require "erb"

module JAXB2Ruby
  class Template  # :nodoc:
    PATHS = Hash[
      Dir[File.expand_path(__FILE__ + "/../../templates/*.erb")].map do |path|
        [File.basename(path, ".erb"), path]
      end
    ]

    DEFAULT = PATHS["roxml"]

    def initialize(name = nil)
      # If it's not a named template assume it's a path
      path = PATHS[name] || name || DEFAULT
      @__erb = ERB.new(File.read(path), nil, "<>%-")
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
