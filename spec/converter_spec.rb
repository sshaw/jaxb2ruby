require "spec_helper"

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

  it "detects classes that are a root xml element" do
    classes = class_hash(convert("address"))
    classes["Address"].element.root?.must_equal(true)
    # Recipient is a root element in the schema...
    # classes["Recipient"].element.root?.must_equal(false)
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

  # TODO: collection types
  describe "ruby data types" do
    it "uses the right type for the given schema type" do
      classes = JAXB2Ruby::Converter.convert(schema("types"))
      nodes = node_hash(classes.first.element)

      { "any"     => "Object",
        "boolean" => :boolean,
        "byte"    => "Fixnum",
        "date"    => "DateTime",
        "day"     => "Fixnum",
        "decimal" => "Float",
        "double"  => "Float",
        "duration"=> "String",
        "id"      => :ID,
        "idref"   => :IDREF,
        "int"     => "Fixnum",
        "long"    => "Fixnum",
        "short"   => "Fixnum",
        "string"  => "String",
        "time"    => "DateTime",
        "year"    => "Fixnum" }.each do |xsd, ruby|

        # xsd type is also the accessor name
        nodes[xsd].wont_be_nil
        nodes[xsd].type.must_equal ruby
      end
    end

    describe "inner classes" do
      # nodes["inner_class"]
    end
  end
end
