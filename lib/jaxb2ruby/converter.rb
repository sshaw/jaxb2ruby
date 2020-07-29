require "find"
require "fileutils"
require "java"

require "jaxb2ruby/xjc"
require "jaxb2ruby/type_util"

module JAXB2Ruby
  class Converter # :nodoc:
    XML_NULL = "\u0000"
    XML_ANNOT_DEFAULT = "##default"

    def self.convert(schema, options = {})
      new(schema, options).convert
    end

    def initialize(schema, options = {})
      raise ArgumentError, "cannot access schema: #{schema}" unless File.file?(schema) and File.readable?(schema)
      @xjc = XJC.new(schema, :xjc => options[:xjc], :wsdl => !!options[:wsdl], :jvm => options[:jvm])

      @namespace = options[:namespace] || {}
      raise ArgumentError, "namespace mapping must be a Hash" unless @namespace.is_a?(Hash)

      @typemap = TypeUtil.new(options[:typemap])
    end

    def convert
      create_java_classes
      create_ruby_classes
    end

    private
    def create_java_classes
      @classes = @xjc.execute
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
      ns = annot.namespace
      Namespace.new(ns) unless ns.blank? or ns == XML_ANNOT_DEFAULT
    end

    def find_namespace(klass)
      annot = klass.get_annotation(javax.xml.bind.annotation.XmlRootElement.java_class) || klass.get_annotation(javax.xml.bind.annotation.XmlType.java_class)
      return unless annot

      # if klass is an inner class the namespace will be on the outter class (enclosing_class).
      annot.namespace == XML_ANNOT_DEFAULT && klass.enclosing_class ?
        find_namespace(klass.enclosing_class) :
        annot.namespace
    end

    def translate_type(klass)
      # Won't work for extract_class() as it expects an instance but this should be split anyways
      return "Object" if klass.java_kind_of?(java.lang.reflect.WildcardType)

      type = @typemap.java2ruby(klass.name)
      return type if type
      return "String" if klass.enum?

      # create_class_name(klass)
      modname = @namespace[find_namespace(klass)]
      ClassName.new(klass.name, modname)
    end

    def resolve_type(field)
      return :ID if field.annotation_present?(javax.xml.bind.annotation.XmlID.java_class)
      return :IDREF if field.annotation_present?(javax.xml.bind.annotation.XmlIDREF.java_class)

      annot = field.get_annotation(javax.xml.bind.annotation.XmlSchemaType.java_class)
      return @typemap.schema2ruby(annot.name) if annot.respond_to?(:name)

      # Limited type checking here (but still maybe too much? it's a tad ugly)
      # should be good enough for List<JAXBElement<Object>> and its variants
      if field.type.name == "java.util.List"
        resolved_type = []
        type = field.generic_type

        if type.java_kind_of?(java.lang.reflect.ParameterizedType)
          type = type.actual_type_arguments.first

          if type.java_kind_of?(java.lang.reflect.ParameterizedType)
            resolved_type << translate_type(type.actual_type_arguments.first)
          # elsif type.java_kind_of?(java.lang.reflect.WildcardType)
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

    # Create a RubyClass for the given Java class.
    def extract_class(klass)
      # Here we expect type to be a ClassName but translate_type can return a String!
      # type = create_class_name(klass)
      type = translate_type(klass)
      element = extract_element(klass)

      dependencies = []
      #dependencies << type.parent_class if type.parent_class

      superclass = nil
      if klass.superclass.name != "java.lang.Object"
        # create_class_name(klass.superclass)
        superclass = translate_type(klass.superclass)
        dependencies << superclass
      end

      (element.children + element.attributes).each do |node|
        # If a node's type isn't predefined, it must be an XML mapped class
        dependencies << node.type if !@typemap.schema_ruby_types.include?(node.type)
      end

      RubyClass.new(type, element, dependencies, superclass)
    end

    # Create elements and attributes from the given Java class' fields
    def extract_elements_nodes(klass)
      nodes = { :attributes => [], :children => [] }

      klass.declared_fields.each do |field|
        if field.annotation_present?(javax.xml.bind.annotation.XmlValue.java_class) || field.annotation_present?(javax.xml.bind.annotation.XmlMixed.java_class)
          nodes[:text] = true
          next if field.annotation_present?(javax.xml.bind.annotation.XmlValue.java_class)
        end

        childopts = { :type => resolve_type(field), :accessor => field.name }
        #childopts[:type] = type # unless Array(type).first == "Object"
        childname = childopts[:accessor]

        if annot = field.get_annotation(javax.xml.bind.annotation.XmlElement.java_class)    ||
                   field.get_annotation(javax.xml.bind.annotation.XmlElementRef.java_class) ||
                   field.get_annotation(javax.xml.bind.annotation.XmlAttribute.java_class)

          childopts[:namespace] = extract_namespace(annot)
          childopts[:required] = annot.respond_to?(:required?) ? annot.required? : false
          childopts[:nillable] = annot.respond_to?(:nillable?) ? annot.nillable? : false

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

    # Create an element from a Java class, turning its fields into elements and attributes
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
      name = name.split(JAVA_CLASS_SEP).last # might be an inner class
      # Should grab annot.prop_order
      # annot = klass.get_annotation(javax.xml.bind.annotation.XmlType.java_class)
      # annot.prop_order are java props here we have element names
      # element.elements.sort_by! { |e| annot.prop_order.index }
      options[:namespace] = extract_namespace(annot)

      Element.new(name, options)
    end

    def valid_class?(klass)
      # Skip Enum for now, maybe forever!
      # TODO: make sure this is a legit class else we can get a const error.
      # For example, if someone uses a namespace that xjc translates into a /javax?/ package
      !klass.enum? && klass.annotation_present?(javax.xml.bind.annotation.XmlType.java_class)
    end

    def extract_classes(java_classes)
      ruby_classes = []
      java_classes.each do |name|
        klass = Java.send(name).java_class.to_java
        next unless valid_class?(klass)
        ruby_classes << extract_class(klass)
      end
      ruby_classes
    end
  end
end
