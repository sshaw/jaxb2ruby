module JAXB2Ruby
  # Maybe...
  # class Namespace < String
  #   def prefix
  #     # something
  #   end
  # end

  class Node
    attr :type
    attr :name
    attr :namespace
    attr :accessor

    def initialize(name, options = {})
      @name = name
      @accessor = name.underscore
      @namespace = options[:namespace]
      @type = options[:type]

      @required = !!options[:required]

      # should have an access
      if @type == :boolean && @accessor.start_with?("is_")
        @accessor["is_"] = ""
        @accessor << "?"
      end
    end

    def required?
      @required
    end
  end

  class Attribute < Node; end

  class Element < Node
    attr :children
    attr :attributes

    def initialize(name, options = {})
      super
      @array = !!options[:array]
      @text = !!options[:text]
      @hash = false
      @children = options[:children] || []
      @attributes = options[:attributes] || []

      # Uhhhh, I think this might need some revisiting, esp. with xsd:enumeration
      if @type.is_a?(Array)
        @accessor = @accessor.pluralize

        if @type.one?
          @array = true
          @type = @type.shift
        else
          @hash = true
        end
      end
    end

    def text?
      @text
    end

    def hash?
      @hash
    end

    def array?
      @array
    end
  end

  class RubyClass
    attr :class
    attr :name
    attr :module
    attr :element

    def initialize(klass, element, dependencies = nil)
      @class = klass
      @name  = klass.demodulize
      @module = klass.deconstantize # >= 3.2
      @element = element
      @dependencies = dependencies || []

      @module.extend Enumerable
      def @module.each(&block)
        split("::").each(&block)
      end

      def @module.to_a
        entries
      end
    end

    def filename
      "#{@name.underscore}.rb"
    end

    def directory
      File.dirname(path)
    end

    def path
      @path ||= make_path(@module.to_a.push(filename))
    end

    def requires
      @requires ||= @dependencies.map { |e| make_path(e.type.split("::")) }.sort
    end

    private
    def make_path(modules)
      modules.map { |name| name.underscore }.join("/")
    end
  end
end
