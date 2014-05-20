require "active_support/core_ext/object/blank"
require "active_support/core_ext/string"

require "jaxb2ruby/version"
require "jaxb2ruby/classes"
require "jaxb2ruby/converter"
require "jaxb2ruby/template"

module JAXB2Ruby
  RUBY_PKG_SEP = "::"
  JAVA_PKG_SEP = "."
  JAVA_CLASS_SEP = "$"

  class Error < StandardError; end
end
