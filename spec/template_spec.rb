require "spec_helper"
require "fileutils"
require "tmpdir"
require "tempfile"

def write(path, classdef)
  File.open(path, "w") { |io| io.puts(classdef) }
end

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

  describe "known templates" do
    let(:paths) { JAXB2Ruby::Template::PATHS }

    %w[happymapper roxml ruby].each do |name|
      it "includes #{name}" do
        File.file?(paths[name]).must_equal(true)
        File.basename(paths[name]).must_equal("#{name}.erb")
      end
    end
  end

  describe "a class created by the ruby template" do
    let(:tmpdir)     { Dir.mktmpdir }
    let(:attributes) {
      Hash[
        :user_name  => "sshaw",
        :first_name => "skye",
        :last_name  => "shaw",
        :numbers    => [1, 2, 3],
        :age        => 0xFF
      ]
    }

    before do
      path = File.join(tmpdir, "user.rb")
      classes = convert("class")

      t = JAXB2Ruby::Template.new("ruby")
      write(path, t.build(classes.first))

      require path
    end

    after { FileUtils.rm_rf(tmpdir) }

    it "has singular read/write accessors for bounded elements" do
      methods = Com::Example::User.instance_methods(false)
      methods.must_include(:user_name)
      methods.must_include(:user_name=)
      methods.must_include(:first_name)
      methods.must_include(:first_name=)
      methods.must_include(:last_name)
      methods.must_include(:last_name=)
    end

    it "has plural read/write accessors for unbounded elements" do
      methods = Com::Example::User.instance_methods(false)
      methods.must_include(:numbers)
      methods.must_include(:numbers=)
    end

    it "has singular read/write accessors for attributes" do
      methods = Com::Example::User.instance_methods(false)
      methods.must_include(:age)
      methods.must_include(:age=)
    end

    describe ".new" do
      it "accepts no arguments" do
        user = Com::Example::User.new
        user.must_be_instance_of(Com::Example::User)
        attributes.each { |name, _| user.send(name).must_be_nil }
      end

      it "accepts a nil argument" do
        user = Com::Example::User.new(nil)
        user.must_be_instance_of(Com::Example::User)
        attributes.each { |name, _| user.send(name).must_be_nil }
      end

      it "initializes instances using values in a Hash argument" do
        user = Com::Example::User.new(attributes)
        user.must_be_instance_of(Com::Example::User)
        attributes.each { |name, value| user.send(name).must_equal(value) }
      end

      # Or, should an ArgumentError be raised?
      it "ignores unknown accessors names in the Hash argument"
    end

    describe "#inspect" do
      it "returns a description of the class' state" do        
      end
    end
  end
end
