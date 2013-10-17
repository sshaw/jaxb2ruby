require "cocaine"
require "find"
require "fileutils"
require "java"
require "tmpdir"

module JAXB2Ruby
  class Converter
    # Not a JRuby way to do this..?
    TYPEMAP = {
      "boolean" => :boolean,
      "byte" => "Fixnum",
      "double" => "Float",
      "float" => "Float",
      "int" => "Fixnum",
      "java.lang.Object" => "Object",
      "java.lang.Boolean" => :boolean,
      "java.lang.Integer" => "Fixnum",
      "java.lang.String" => "String",
      "java.math.BigDecimal" => "Float",
      "java.math.BigInteger" => "Fixnum",
      "javax.xml.datatype.Duration" => "String",
      "javax.xml.datatype.XMLGregorianCalendar" => "DateTime",
      "long" => "Fixnum",
      "short" => "Fixnum"
      # others...
    }

    XML_NULL = "\u0000"
    XML_ANNOT_DEFAULT = "##default"
    XJC_CONFIG = File.expand_path(__FILE__ + "/../../xjc/config.xjb")

    # https://github.com/thoughtbot/cocaine/issues/24
    Cocaine::CommandLine.runner = Cocaine::CommandLine::BackticksRunner.new

    def self.convert(schema, options = {})
      new(schema, options).convert
    end

    def initialize(schema, options = {})
      @schema = schema
      raise ArgumentError, "cannot access schema: #@schema" unless File.file?(@schema) and File.readable?(@schema)

      @namespace = options[:namespace] || {}
      raise ArgumentError, "namespace mapping muse be a Hash" unless Hash === @namespace

      @typemap = Hash === options[:typemap] ? TYPEMAP.merge(options[:typemap]) : TYPEMAP
    end

    def convert
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
      line  = Cocaine::CommandLine.new("xjc", "-extension -npa -d :sources :schema -b :config ")
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
      extract_classes(java_classes)
    rescue IOError, SystemCallError => e
      raise Error, "failed to generate ruby class: #{e}"
    end

    def find_java_classes(root)
      # Without this, parent dir removal below could leave "/" at the start of a non-root path
      # why do we need exapand though..?
      root = File.expand_path(root) << "/" unless root.end_with?("/")
      classes = []

      Find.find(root) do |path|
        if File.file?(path) && File.extname(path) == ".class"
          path[root] = ""   # Want com/example/Class not root/com/example/Class
          classes << path
        end
      end

      classes.map { |path| java_name_from_path(path) }
    end

    def java_name_from_path(path)
      klass = path.split(%r{/}).join(".")
      klass[%r{\.class\Z}] = ""
      klass
    end

    def extract_namespace(annot)
      Namespace.new(annot.namespace) unless annot.namespace == XML_ANNOT_DEFAULT
    end

    def find_namespace(klass)
      annot = klass.get_annotation(javax.xml.bind.annotation.XmlRootElement.java_class) || klass.get_annotation(javax.xml.bind.annotation.XmlType.java_class)
      return unless annot

      annot.namespace == XML_ANNOT_DEFAULT && klass.enclosing_class ?
        find_namespace(klass.enclosing_class) :
        annot.namespace
    end

    def translate_type(klass)
      return @typemap[klass.name] if @typemap.include?(klass.name)
      return "String" if klass.enum?

      type = klass.name
      if modname = @namespace[find_namespace(klass)]
        type.sub!("#{klass.get_package.name}.", "#{modname}::")
      end

      ClassName.new(type)
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
      type = translate_type(klass)
      element = extract_element(klass)

      dependencies = []
      dependencies << type.parent_class if type.parent_class
      # If a String type isn't in the *original* typemap, it must be an XML mapped class
      (element.children + element.attributes).each do |node|
        dependencies << node.type if node.type.is_a?(String) and !TYPEMAP.values.include?(node.type)
      end

      RubyClass.new(type, element, dependencies)
    end

    def extract_elements_nodes(klass)
      nodes = { :attributes => [], :children => [] }

      klass.declared_fields.each do |field|
        if annot = field.get_annotation(javax.xml.bind.annotation.XmlElement.java_class) || field.get_annotation(javax.xml.bind.annotation.XmlAttribute.java_class)
          childopts = { :namespace => extract_namespace(annot), :required => annot.required?, :type => resolve_type(field) }
          childname = annot.name == XML_ANNOT_DEFAULT ? field.name : annot.name

          # Not all implementations support default values for attributes
          if annot.respond_to?(:default_value) 
            childopts[:default] = annot.default_value == XML_NULL ? nil : annot.default_value
          end

          if annot.is_a?(javax.xml.bind.annotation.XmlElement)
            nodes[:children] << Element.new(childname, childopts)
          else
            nodes[:attributes] << Attribute.new(childname, childopts)
          end
        elsif field.annotation_present?(javax.xml.bind.annotation.XmlValue.java_class)
          nodes[:text] = true
        else
          warn "warning: cannot extract element/attribute from: #{klass.name}.#{field.name})"
        end
      end

      nodes
    end

    def extract_element(klass)
      options = extract_elements_nodes(klass)

      if annot = klass.get_annotation(javax.xml.bind.annotation.XmlRootElement.java_class)
        name = annot.name
        options[:root] = true
      end

      if name.blank?
        annot = klass.get_annotation(javax.xml.bind.annotation.XmlType.java_class)
        name  = annot.name
      end

      name = klass.name if name.blank?
      name = name.split("$").last # might be an inner class

      # Should grab annot.prop_order
      # annot.prop_order are java props here we have element names
      # element.elements.sort_by! { |e| annot.prop_order.index }
      options[:namespace] = extract_namespace(annot)

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
