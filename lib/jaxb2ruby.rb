require "active_support/core_ext/string"
require "active_support/inflector"
require "jaxb2ruby/classes"
require "jaxb2ruby/converter"

module JAXB2Ruby  
  class Error < StandardError; end

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
