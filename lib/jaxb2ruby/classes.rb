require "forwardable"

module JAXB2Ruby
  class ClassName < String  # :nodoc:
    attr :module
    attr :outter_class  # if java inner class, if any
    attr :name          # module + outter_class + basename
    attr :basename

    # Turn a java class name into a ruby class name, with accessors for various parts
    def initialize(java_name, rubymod = nil)
      pkg = java_name.split(JAVA_PKG_SEP)
      pkg = rubymod ? [rubymod, ns2mod(pkg[-1])] : pkg.map { |part| ns2mod(part) }

      parts = pkg.pop.split(JAVA_CLASS_SEP)
      @basename = parts.pop
      @outter_class = parts.join(RUBY_PKG_SEP)
      @module = rubymod || pkg.join(RUBY_PKG_SEP)
      @name = [@module, @outter_class, @basename].reject(&:empty?).join(RUBY_PKG_SEP)

      super @name
    end

    private
    def ns2mod(pkg)
      pkg.sub(/\A_/, "V").camelize
    end
  end

  class Namespace < String # :nodoc:
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
    attr :local_name
    attr :namespace
    attr :accessor
    attr :default

    def initialize(name, options = {})
      @name = @local_name = name

      @accessor = (options[:accessor] || name).underscore
      # If this conflicts with a Java keyword it will start with an underscore
      @accessor.sub!(/\A_/, "")

      @namespace = options[:namespace]
      @name = sprintf "%s:%s", @namespace.prefix, @name if @namespace

      @default = options[:default]
      @type = options[:type]
      @required = !!options[:required]
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
    extend Forwardable

    attr :module
    attr :outter_class
    attr :superclass
    attr :element

    def_delegators :@type, :name, :basename, :to_s

    def initialize(type, element, dependencies = nil, superclass = nil)
      @type = type
      @element = element
      @dependencies = dependencies || []
      @superclass = superclass

      @module = @type.module.dup unless @type.module.empty?
      @outter_class = @type.outter_class.dup unless @type.outter_class.empty?

      [@module, @outter_class].each do |v|
        v.extend Enumerable

        # v may be NilClass
        def v.each(&block)
          ( nil? ? [] : split(RUBY_PKG_SEP) ).each(&block)
        end
      end
    end

    def filename
      "#{basename.underscore}.rb"
    end

    def directory
      File.dirname(path)
    end

    # This class's path, for passing to +require+.
    # <code>Foo::Bar::OneTwo</code> will be turned into <code>foo/bar/one_two</code>.
    #
    def path
      @path ||= make_path(@module.to_a.concat(outter_class.to_a).push(filename))
    end

    # Paths for all of this class's dependencies, for passing to +require+.
    #
    def requires
      @requires ||= @dependencies.map { |e| make_path(e.split(RUBY_PKG_SEP)) }.sort.uniq
    end

    private
    def make_path(modules)
      modules.map { |name| name.underscore }.join("/")
    end
  end
end
