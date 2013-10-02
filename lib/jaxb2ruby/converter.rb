require "cocaine"
require "find"
require "fileutils"
require "java"
require "tmpdir"

module JAXB2Ruby
  class Converter

    lib = File.expand_path(__FILE__ + "/../..")

    TEMPLATES = Hash[
      Dir[lib + "/templates/*.erb"].map do |path|
        [File.basename(path, ".erb"), path]
      end
    ]

    DEFAULT_TEMPLATE = TEMPLATES["roxml"]

    # Not a JRuby way to do this..?
    TYPEMAP = {
      "boolean" => :boolean,
      "java.lang.Boolean" => :boolean,
      "java.lang.String" => "String",
      "java.lang.Integer" => "Integer",
      "java.math.BigDecimal" => "Integer",
      "java.math.BigInteger" => "Integer",
      "javax.xml.datatype.Duration" => "String",
      "javax.xml.datatype.XMLGregorianCalendar" => "DateTime",
      # others...
    }

    XJC_CONFIG = lib + "/xjc/config.xjb"

    # https://github.com/thoughtbot/cocaine/issues/24
    Cocaine::CommandLine.runner = Cocaine::CommandLine::BackticksRunner.new

    def initialize(schema, options = {})
      @schema = schema
      raise ArgumentError, "cannot access schema: #@schema" unless File.file?(@schema) and File.readable?(@schema)

      # If it's not a named template assume it's a path
      @template = Template.new(TEMPLATES[options[:template]] || options[:template] || DEFAULT_TEMPLATE)

      @namespace = options[:namespace] || {}
      raise ArgumentError, "namespace mapping muse be a Hash" unless Hash === @namespace

      @output  = options[:output] || "ruby"
      @typemap = Hash === options[:typemap] ? TYPEMAP.merge(options[:typemap]) : TYPEMAP
    end

    def run
      setup_tmpdirs
      create_java_classes
      create_ruby_classes
    ensure
      FileUtils.rm_rf(@tmproot) if @tmproot
    end

    private
    def setup_tmpdirs
      @tmproot = Dir.mktmpdir
      @classes = File.join(@tmproot, "classes")
      @sources = File.join(@tmproot, "source")
      [@classes, @sources].each { |dir| Dir.mkdir(dir) }
    rescue IOErorr, SystemCallError => e
      raise Error, "error creating temp directories: #{e}"
    end

    def create_java_classes
      xjc
      javac
    end

    def xjc
      line  = Cocaine::CommandLine.new("xjc", "-extension -d :sources :schema -b :config ")
      line.run(:schema => @schema, :sources => @sources, :config => XJC_CONFIG)
    rescue Cocaine::ExitStatusError => e
      raise Error, "xjc execution failed: #{e}"
    rescue Cocaine::CommandNotFoundError => e
      raise command_not_found("xjc")
    end

    def javac
      # https://github.com/thoughtbot/cocaine/pull/56
      files = Dir[ File.join(@sources, "/**/*.java") ]
      keys = 1.upto(files.size).map { |n| "{file#{n}}" }
      argv = Hash[keys.zip(files)].merge(:classes => @classes)

      line = Cocaine::CommandLine.new("javac", "-d :classes " << keys.map { |key| ":#{key}" }.join(" "))
      line.run(argv)
    rescue Cocaine::ExitStatusError => e
      raise Error, "javac execution failed: #{e}"
    rescue Cocaine::CommandNotFoundError => e
      raise command_not_found("javac")
    end

    def create_ruby_classes
      java_classes = find_java_classes(@classes)
      raise Error, "no classes were generated from the schema" if java_classes.empty?

      $CLASSPATH << @classes unless $CLASSPATH.include?(@classes)
      ruby_classes = extract_classes(java_classes)

      ruby_classes.each do |klass|
        puts "generating: #{klass.path}"
        FileUtils.mkdir_p(File.join(@output, klass.directory))
        File.open(File.join(@output, klass.path), "w") { |io| io.puts @template.build(klass) }
      end

    rescue IOError, SystemCallError => e
      raise Error, "failed to generate ruby class: #{e}"
    end

    def find_java_classes(root)
      # Without this, parent dir removal below could leave "/" at the start of a non-root path
      # why do we need exapand though..?
      root = File.expand_path(root) << "/" unless root.end_with?("/")
      classes = []

      Find.find(root) do |path|
        if File.file?(path) && File.extname(path) == ".class" && !File.basename(path).start_with?("package-info.")
          path[root] = ""   # Want com/example/Class not root/com/example/Class
          classes << path
        end
      end

      classes.map { |path| java_name_from_path(path) }
    end

    def ruby_name_from_java(pkg)
      pkg.to_s.split(".")[1..-1].map { |s|
        s.sub(/\A_/, "V").camelize
      }.join "::"
    end

    def java_name_from_path(path)
      klass = path.split(%r{/}).join(".")
      klass[%r{\.class\Z}] = ""
      klass
    end

    def extract_namespace(klass)
      pkg = klass.package
      ns = pkg.get_annotation(javax.xml.bind.annotation.XmlSchema.java_class)
      ns.namespace if ns
    end

    def translate_type(klass)
      translate_type_ignore_inner_class(klass).gsub("$", "::")
    end

    def translate_type_ignore_inner_class(klass)
      return @typemap[klass.name] if @typemap.include?(klass.name)
      return "String" if klass.enum?

      if modname = @namespace[extract_namespace(klass)]
        type = klass.name
        type.sub!("#{klass.get_package.name}.", "#{modname}::")
      else
        ruby_name_from_java(klass.name)
      end
    end

    def resolve_type(field)
      return :ID if field.annotation_present?(javax.xml.bind.annotation.XmlID.java_class)
      return :IDREF if field.annotation_present?(javax.xml.bind.annotation.XmlIDREF.java_class)

      type = field.generic_type
      if type.java_kind_of?(java.lang.reflect.ParameterizedType) #||
        #type.java_kind_of?(Java::java.lang.reflect.GenericArrayType) ||
        #type.java_kind_of?(Java::java.lang.reflect.TypeVariable)
        type.actual_type_arguments.map { |t| translate_type(t) }
      else
        # should probably capture enum values
        translate_type(type)
      end
    end

    def extract_class(klass)
      type = translate_type_ignore_inner_class(klass)
      element = extract_element(klass)
      # If a String type isn't in the *original* typemap, it must be a XML mapped class
      # TODO: If this is an inner class we need to add the parent
      dependencies = (element.children + element.attributes).select { |node| node.type.is_a?(String) and !TYPEMAP.values.include?(node.type) }
      RubyClass.new(type, element, dependencies)
    end

    def extract_element(klass)
      options = {
        :namespace  => extract_namespace(klass),
        :attributes => [],
        :children   => []
      }

      klass.declared_fields.each do |field|
        annot = field.get_annotation(javax.xml.bind.annotation.XmlElement.java_class)
        if annot
          options[:children] << Element.new(annot.name, :type => resolve_type(field), :required => annot.required?)
        elsif field.annotation_present?(javax.xml.bind.annotation.XmlValue.java_class)
          options[:text] = true
        elsif annot = field.get_annotation(javax.xml.bind.annotation.XmlAttribute.java_class)
          options[:attributes] << Attribute.new(annot.name, :type => resolve_type(field), :required => annot.required?)
        else
          warn "warning: cannot extract element/attribute from: #{klass.name}.#{field.name})"
        end
      end

      # Get the element's name
      annot = klass.get_annotation(javax.xml.bind.annotation.XmlType.java_class)
      name  = annot.name
      if name.empty?
        annot = klass.get_annotation(javax.xml.bind.annotation.XmlRootElement.java_class)
        name  = annot ? annot.name : klass.name.split("$").last # might be an inner class
      end

      # Should grab annot.prop_order
      # annot.prop_order are java props here we have element names
      # element.elements.sort_by! { |e| annot.prop_order.index }
      Element.new(name, options)
    end

    def valid_class?(klass)
      return false if klass.java_class.enum?  # Skip Enum for now, maybe for ever!
      return false if klass.java_class.annotation_present?(javax.xml.bind.annotation.XmlRegistry.java_class)
      return false unless klass.java_class.annotation_present?(javax.xml.bind.annotation.XmlType.java_class) or
        klass.java_class.annotation_present?(javax.xml.bind.annotation.XmlRootElement.java_class)
      true
    end

    def extract_classes(java_classes)
      ruby_classes = []
      java_classes.each do |name|
        klass = Java.send(name)
        next unless valid_class?(klass)
        ruby_classes << extract_class(klass.new.get_class)
      end
      ruby_classes
    end

    def command_not_found(cmd)
      JAXB2Ruby::Error.new("#{cmd} command not found, is it in your PATH enviornment variable?")
    end
  end
end