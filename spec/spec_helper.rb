require "minitest/autorun"
require "jaxb2ruby"


def schema(name)
  File.expand_path("../fixtures/#{name}.xsd", __FILE__)
end

def convert(xsd, options = {})
  JAXB2Ruby::Converter.convert(schema(xsd), options)
end

def class_hash(classes)
  Hash[ classes.map { |klass| [ klass.name, klass ] } ]
end

def node_hash(element)
  Hash[ (element.children + element.attributes).map { |node| [node.name, node] } ]
end
