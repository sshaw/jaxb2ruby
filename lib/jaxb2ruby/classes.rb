module JAXB2Ruby
  class ClassName < String
    attr :class               # module + class
    attr :name                # class
    attr :module              # module
    attr :parent_class        # if java inner class

    # Turn a java class name into a ruby class name, keeping inner classes inner
    def initialize(java_name, rubymod = nil)
      pkg = java_name.split(".")
      pkg = rubymod ? [rubymod, ns2mod(pkg[-1])] : pkg.map { |part| ns2mod(part) }

      @class = pkg.join("::")
      @name = @class.demodulize.gsub("$", "::")
      @module = rubymod || @class.deconstantize
      @parent_class = sprintf "%s::%s", @module, @name.sub(/::\w+\Z/,"") if @class.gsub!("$", "::")

      super @class
    end

    private
    def ns2mod(pkg)
      pkg.sub(/\A_/, "V").camelize
    end
  end

  class Namespace < String
    counter = 0
    @@prefixes = Hash.new { |h,ns|  h[ns] = "ns#{counter+=1}".freeze }

    attr :name
    attr :prefix

    def initialize(name)
      @name   = name
      @prefix = @@prefixes[name]
      super
    end
  end

  class Node
    attr :type
    attr :name
    attr :namespace
    attr :accessor
    attr :default

    def initialize(name, options = {})
      @name = name
      @accessor = (options[:accessor] || name).underscore
      @namespace = options[:namespace]
      @default = options[:default]
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

  # TODO: nillable
  class Element < Node
    attr :children
    attr :attributes

    def initialize(name, options = {})
      super
      @array = !!options[:array]
      @text = !!options[:text]
      @root = !!options[:root]
      @nillable = !!options[:nillable]
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

    def nillable?
      @nillable
    end

    def root?
      @root
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
    attr :element
    attr :name
    attr :module
    attr :superclass

    def initialize(type, element, dependencies = nil, superclass = nil)
      @class = type
      @name  = type.name
      @module = type.module.dup
      @element = element
      @dependencies = dependencies || []
      @superclass = superclass

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
      @requires ||= @dependencies.map { |e| make_path(e.split("::")) }.sort.uniq
    end

    private
    def make_path(modules)
      modules.map { |name| name.underscore }.join("/")
    end
  end
end
