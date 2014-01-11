require "spec_helper"
require "jaxb2ruby/type_util"

describe JAXB2Ruby::Converter do
  it "creates ruby classes" do
    classes = convert("address")
    classes.size.must_equal(2)

    hash = class_hash(classes)
    hash["Address"].must_be_instance_of(JAXB2Ruby::RubyClass)
    hash["Address"].class.must_equal("Com::Example::Address")
    hash["Address"].module.must_equal("Com::Example")
    hash["Address"].name.must_equal("Address")

    hash["Recipient"].must_be_instance_of(JAXB2Ruby::RubyClass)
    hash["Recipient"].class.must_equal("Com::Example::Recipient")
    hash["Recipient"].module.must_equal("Com::Example")
    hash["Recipient"].name.must_equal("Recipient")
  end

  it "creates inner classes from complex anonymous types" do
    hash = class_hash(convert("types"))
    hash["Types::NestedClass"].must_be_instance_of(JAXB2Ruby::RubyClass)
    hash["Types::NestedClass"].class.must_equal("Com::Example::Types::Types::NestedClass")
    hash["Types::NestedClass"].module.must_equal("Com::Example::Types")
    hash["Types::NestedClass"].name.must_equal("Types::NestedClass")
  end

  it "creates an element for each class" do
    classes = convert("address")

    hash = class_hash(classes)
    hash["Address"].element.must_be_instance_of(JAXB2Ruby::Element)
    hash["Address"].element.name.must_equal("Address")
    hash["Address"].element.namespace.must_equal("http://example.com")

    hash["Recipient"].element.must_be_instance_of(JAXB2Ruby::Element)
    hash["Recipient"].element.name.must_equal("Recipient")
  end

  it "creates the right child elements for each class' element" do
    classes = convert("address")
    hash = class_hash(classes)

    elements = class_hash(hash["Address"].element.children)
    elements.size.must_equal(5)
    %w[House Street Town County Country].each do |name|
      elements[name].must_be_instance_of(JAXB2Ruby::Element)
      elements[name].accessor.must_equal(name.underscore)
      elements[name].type.must_equal("String")
    end

    elements = class_hash(hash["Recipient"].element.children)
    elements.size.must_equal(2)
    %w[FirstName LastName].each do |name|
      elements[name].must_be_instance_of(JAXB2Ruby::Element)
      elements[name].accessor.must_equal(name.underscore)
      elements[name].type.must_equal("String")
    end
  end

  it "creates the right attributes for each class" do
    classes = convert("address")
    hash = class_hash(classes)

    hash["Address"].element.attributes.size.must_equal(1)
    attr = hash["Address"].element.attributes.first
    attr.name.must_equal("PostCode")
    attr.accessor.must_equal("post_code")
    attr.type.must_equal("String")

    hash["Recipient"].element.attributes.must_be_empty
  end

  it "cretates predicate attribute readers for boolean elements" do
    skip "thinking about this one..."
    classes = class_hash(convert("types"))
    nodes = node_hash(classes["Types"].element)
    nodes["boolean"].accessor.must_equal("boolean?")
  end

  it "detects classes that are a root xml element" do
    classes = class_hash(convert("types"))
    classes["Types"].element.root?.must_equal(true)
    classes["Types::NestedClass"].element.root?.must_equal(false)
  end

  it "detects classes that are arrays" do
    classes = class_hash(convert("types"))
    nodes = node_hash(classes["Types"].element)
    nodes["idrefs"].wont_be_nil
    nodes["idrefs"].array?.must_equal(true)
    nodes["idrefs"].type.must_equal("Object")

    nodes["anyType"].must_be_instance_of(JAXB2Ruby::Element)
    nodes["anyType"].array?.must_equal(false)
  end

  it "detects classes that contain text nodes" do
    classes = class_hash(convert("types"))
    classes["Types"].element.text?.must_equal(false)
    classes["TextType"].element.text?.must_equal(true)
  end

  it "detects elements that are required" do
    classes = class_hash(convert("address"))
    required = node_hash(classes["Recipient"].element).select { |_, v| v.required? }
    required.size.must_equal(2)
    required.must_include("FirstName")
    required.must_include("LastName")

    required = node_hash(classes["Address"].element).select { |_, v| v.required? }
    required.size.must_equal(4)
    %w[House Street Town PostCode].each { |attr| required.must_include(attr) }
  end

  it "detects attributes that are required" do
    classes = class_hash(convert("address"))
    required = classes["Recipient"].element.attributes.select { |_, v| v.required? }
    required.must_be_empty

    required = class_hash(classes["Address"].element.attributes).select { |_, v| v.required? }
    required.size.must_equal(1)
    required.first.must_include("PostCode")
  end

  it "detects element defaults" do
    classes = class_hash(convert("address"))
    defaults = class_hash(classes["Recipient"].element.children).reject { |_, v| v.default.nil? }
    defaults.must_be_empty

    defaults = class_hash(classes["Address"].element.children).reject { |_, v| v.default.nil? }
    defaults.size.must_equal(1)
    defaults.must_include("Country")
    defaults["Country"].default.must_equal("US")
  end

  it "detects attribute defaults" do
    skip "No all XJC implementations support attribute defaults... but we do"
  end

  describe "given a namespace to module mapping" do
    let(:mod)   { "A::Namespace" }
    let(:nsmap) { { "http://example.com" => mod } }

    it "converts elements in the given namespace to the classes in the given module" do
      hash = class_hash(convert("address", :namespace => nsmap))
      hash["Address"].must_be_instance_of(JAXB2Ruby::RubyClass)
      hash["Address"].class.must_equal("#{mod}::Address")
      hash["Address"].module.must_equal(mod)
      hash["Address"].name.must_equal("Address")
    end
  end

  describe "given an XML Schema type to Ruby type mapping" do
    let(:typemap) { {
        "anySimpleType" => "My::Type",
        "boolean" => "TrueClass"
     } }

    # describe "elements without a mapping" do
    # it "does not convert them" do
    # end
    # end

    describe "elements with a mapping" do
      it "converts them to the given classes" do
        classes = class_hash(convert("types", :typemap => typemap))
        nodes = node_hash(classes["Types"].element)
        typemap.each do |xsd, ruby|
          nodes[xsd].must_be_instance_of(JAXB2Ruby::Element)
          nodes[xsd].type.must_equal(ruby)
        end
      end
    end
  end

  describe "XML schema to ruby data type mapping" do
    let(:nodes) {
      classes = class_hash(convert("types"))
      node_hash(classes["Types"].element)
    }

    JAXB2Ruby::TypeUtil::SCHEMA_TO_RUBY.each do |xsd, ruby|
      it "maps #{xsd} elements to #{ruby}" do
        # xsd type is also the accessor name
        nodes[xsd].must_be_instance_of(JAXB2Ruby::Element)
        nodes[xsd].type.must_equal(ruby)
      end
    end
  end
end
