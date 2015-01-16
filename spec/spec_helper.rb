require "minitest/autorun"
require "jaxb2ruby"


def schema(name)
  File.expand_path("../fixtures/#{name}.xsd", __FILE__)
end

def convert(xsd, options = {})
  JAXB2Ruby::Converter.convert(schema(xsd), options)
end

def class_hash(classes)
  # classes can be a Node or a RubyClass
  pairs = classes.map { |klass| [ klass.respond_to?(:basename) ? klass.basename : klass.local_name, klass ] }
  Hash[ pairs ]
end

def node_hash(element)
  Hash[ (element.children + element.attributes).map { |node| [node.local_name, node] } ]
end

def assert_equal_modulo_comments(a, b)
  assert_equal a, b.gsub(/^#.*\n/, '')
end
