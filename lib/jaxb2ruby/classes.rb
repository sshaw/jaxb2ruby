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

    def initialize(klass, element)
      @class = klass
      @name  = klass.demodulize
      @module = klass.deconstantize # >= 3.2
      @element = element

      @module.extend Enumerable
      def @module.each(&block)
        split("::").each(&block)
      end

      def @module.to_a
        entries
      end
    end

    def filename
      "#@name.rb"
    end

    def directory
      File.dirname(path)
    end

    def path
      @path ||= @module.to_a.push(filename).map { |mod| mod.underscore }.join("/")
    end

    # Bit of a last second hack here :(
    def requires
      @requires ||= begin
        req = []
        (element.children + element.attributes).each do |node|
          # Only select types that look like a module          
          # If this is going to be used, we'll have to check !TYPEMAP.values.include? else a 
          # user-defined type mapping to a class with no module won't be required
          if node.type.is_a?(String) and node.type.include?("::")
            req << node.type.split("::").map { |mod| mod.underscore }.join("/")
          end
        end
        req.sort
      end
    end
  end
end
