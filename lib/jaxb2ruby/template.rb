require "erb"

module JAXB2Ruby
  class Template
    def initialize(path)
      @__erb ||= ERB.new(File.read(path), nil, "<>%-")
      @version = JAXB2Ruby::VERSION
    rescue => e
      raise Error, "cannot load class template: #{e}"
    end

    def build(klass)
      @class = klass
      @__erb.result(binding)
    end
  end
end
