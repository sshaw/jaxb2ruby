require "active_support/core_ext/string"
require "active_support/inflector"
require "jaxb2ruby/classes"
require "jaxb2ruby/converter"

module JAXB2Ruby  
  class Error < StandardError; end

  TEMPLATES = Hash[
    Dir[File.expand_path(File.dirname(__FILE__)) << "/templates/*.erb"].map do |path|
      [File.basename(path, ".erb"), path]
    end
  ]

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
end
