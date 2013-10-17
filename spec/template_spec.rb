require "spec_helper"
require "tempfile"

describe JAXB2Ruby::Template do
  it "uses the default template if none is given" do
    # use the template's path as the template
    File.stub :read, lambda { |path| path } do
      t = JAXB2Ruby::Template.new
      t.build(nil).must_equal(JAXB2Ruby::Template::DEFAULT)
    end
  end

  it "uses the template provided as an argument" do
    file = Tempfile.new("jaxb2ruby")
    file.write("DATA")
    file.close

    t = JAXB2Ruby::Template.new(file.path)
    t.build(nil).must_equal("DATA")
  end

  it "raises an error if the template can't be read" do
    lambda { JAXB2Ruby::Template.new("blah!") }.must_raise(JAXB2Ruby::Error, /cannot load/)
  end

  it "passes the given class to the template" do
    file = Tempfile.new("jaxb2ruby")
    file.write("<%= @class.name %>")
    file.close

    klass = Struct.new(:name).new("sshaw")
    t = JAXB2Ruby::Template.new(file.path)
    t.build(klass).must_equal("sshaw")
  end

  it "builds a list of the available templates"
end
