require "cocaine"
require "find"
require "fileutils"
require "java"
require "tmpdir"

require "jaxb2ruby/type_util"

module JAXB2Ruby
  class Converter
    XML_NULL = "\u0000"
    XML_ANNOT_DEFAULT = "##default"
    XJC_CONFIG = File.expand_path(__FILE__ + "/../../xjc/config.xjb")

    def self.convert(schema, options = {})
      new(schema, options).convert
    end

    def initialize(schema, options = {})
      @schema = schema
      raise ArgumentError, "cannot access schema: #@schema" unless File.file?(@schema) and File.readable?(@schema)

      @namespace = options[:namespace] || {}
      raise ArgumentError, "namespace mapping muse be a Hash" unless Hash === @namespace

      @usewsdl = options[:wsdl] || false
      @typemap = TypeUtil.new(options[:typemap])
    end

    def convert
      setup_tmpdirs
      create_java_classes
      create_ruby_classes
    ensure
      FileUtils.rm_rf(@tmproot) if @tmproot
    end

    private
    ### Exec class

    # https://github.com/thoughtbot/cocaine/issues/24
    Cocaine::CommandLine.runner = Cocaine::CommandLine::BackticksRunner.new

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
      options = @schema.end_with?(".wsdl") || @usewsdl ? "-wsdl " : ""
      options << "-extension -npa -d :sources :schema -b :config"
      line  = Cocaine::CommandLine.new("xjc", options)
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
    ### Exec class

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
      type = @typemap.java2ruby(klass.name)
      return type if type
      return "String" if klass.enum?

      modname = @namespace[find_namespace(klass)]
      ClassName.new(klass.name, modname)
    end

    def resolve_type(field)
      return :ID if field.annotation_present?(javax.xml.bind.annotation.XmlID.java_class)
      return :IDREF if field.annotation_present?(javax.xml.bind.annotation.XmlIDREF.java_class)

      annot = field.get_annotation(javax.xml.bind.annotation.XmlSchemaType.java_class)
      return @typemap.schema2ruby(annot.name) if annot

      # Very limited type checking here, should be good enough for what we deal with
      if field.type.name == "java.util.List"
        resolved_type = []
        type = field.generic_type

        if type.java_kind_of?(java.lang.reflect.ParameterizedType)
          type = type.actual_type_arguments.first

          if type.java_kind_of?(java.lang.reflect.ParameterizedType)
            resolved_type << translate_type(type.actual_type_arguments.first)
          # elsif type.java_kind_of?(java.lang.reflectype.WildcardType)
          #   type.get_upper_bounds.each do |lower|
          #   end
          #   type.get_lower_bounds.each do |upper|
          #   end
          else
            resolved_type << translate_type(type)
          end
        end

        return resolved_type
      end

      translate_type(field.type)
    end

    def extract_class(klass)
      type = translate_type(klass)
      element = extract_element(klass)

      dependencies = []
      dependencies << type.parent_class if type.parent_class
      # If a node's type isn't predefined, it must be an XML mapped class
      (element.children + element.attributes).each do |node|
        dependencies << node.type if !@typemap.schema_ruby_types.include?(node.type)
      end

      RubyClass.new(type, element, dependencies)
    end

    def extract_elements_nodes(klass)
      nodes = { :attributes => [], :children => [] }

      klass.declared_fields.each do |field|
        if field.annotation_present?(javax.xml.bind.annotation.XmlValue.java_class)
          nodes[:text] = true
          next
        end

        childopts = { :type => resolve_type(field) }
        #childopts[:type] = type # unless Array(type).first == "Object"
        childname = field.name

        if annot = field.get_annotation(javax.xml.bind.annotation.XmlElement.java_class)    ||
                   field.get_annotation(javax.xml.bind.annotation.XmlElementRef.java_class) ||  # shouldn't need this
                   field.get_annotation(javax.xml.bind.annotation.XmlAttribute.java_class)

          childopts[:namespace] = extract_namespace(annot)
          childopts[:required] = annot.respond_to?(:required?) ? annot.required? : false

          childname = annot.name if annot.name != XML_ANNOT_DEFAULT

          # Not all implementations support default values for attributes
          if annot.respond_to?(:default_value)
            childopts[:default] = annot.default_value == XML_NULL ? nil : annot.default_value
          end
        end

        if field.annotation_present?(javax.xml.bind.annotation.XmlAttribute.java_class)
          nodes[:attributes] << Attribute.new(childname, childopts)
        else
          nodes[:children] << Element.new(childname, childopts)
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
      # annot = klass.get_annotation(javax.xml.bind.annotation.XmlType.java_class)
      # annot.prop_order are java props here we have element names
      # element.elements.sort_by! { |e| annot.prop_order.index }
      options[:namespace] = extract_namespace(annot)

      Element.new(name, options)
    end

    def valid_class?(klass)
      # Skip Enum for now, maybe for ever!
      # TODO: make sure this is a legit class else we can get a const error.
      # For example, if someone uses a namespace that xjc translates into a /javax?/ package
      !klass.java_class.enum? && klass.java_class.annotation_present?(javax.xml.bind.annotation.XmlType.java_class)
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
