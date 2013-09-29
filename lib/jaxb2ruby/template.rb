require "erb"

module JAXB2Ruby
  class Template
    def initialize(path)
      @__erb ||= ERB.new(File.read(path))
    rescue => e
      raise Error, "cannot load ruby class template: #{e}"
    end

    def build(klass)
      @class = klass
      @__erb.result(binding)
    end
  end
end
