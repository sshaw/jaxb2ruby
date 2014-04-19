require "tmpdir"
require "cocaine"

module JAXB2Ruby
  class XJC  # :nodoc:
    XJC_CONFIG = File.expand_path(__FILE__ + "/../../xjc/config.xjb")

    # https://github.com/thoughtbot/cocaine/issues/24
    Cocaine::CommandLine.runner = Cocaine::CommandLine::BackticksRunner.new

    def initialize(schema, options = {})
      @schema  = schema
      @options = options
      setup_tmpdirs
    end

    def execute
      xjc
      javac
      @classes
    end

    private
    def setup_tmpdirs
      @tmproot = Dir.mktmpdir
      @classes = File.join(@tmproot, "classes")
      @sources = File.join(@tmproot, "source")
      [@classes, @sources].each { |dir| Dir.mkdir(dir) }
    rescue IOErorr, SystemCallError => e
      raise Error, "error creating temp directories: #{e}"
    end

    def xjc
      options = @schema.end_with?(".wsdl") || @options[:wsdl] ? "-wsdl " : ""
      options << "-extension -npa -d :sources :schema -b :config"
      line = Cocaine::CommandLine.new("xjc", options)
      line.run(:schema => @schema, :sources => @sources, :config => XJC_CONFIG)
    rescue Cocaine::ExitStatusError => e
      raise Error, "xjc execution failed: #{e}"
    rescue Cocaine::CommandNotFoundError => e
      raise command_not_found("xjc")
    end

    def javac
      # https://github.com/thoughtbot/cocaine/pull/56
      files = Dir[ File.join(@sources, "/**/*.java") ]
      keys = 1.upto(files.size).map { |n| "{file#{n}}" }
      argv = Hash[keys.zip(files)].merge(:classes => @classes)

      line = Cocaine::CommandLine.new("javac", "-d :classes " << keys.map { |key| ":#{key}" }.join(" "))
      line.run(argv)
    rescue Cocaine::ExitStatusError => e
      raise Error, "javac execution failed: #{e}"
    rescue Cocaine::CommandNotFoundError => e
      raise command_not_found("javac")
    end
  end
end
