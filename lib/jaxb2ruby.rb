require "active_support/inflector"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/string"

require "jaxb2ruby/classes"
require "jaxb2ruby/converter"
require "jaxb2ruby/template"

module JAXB2Ruby
  VERSION = "0.0.1"

  class Error < StandardError; end
end
