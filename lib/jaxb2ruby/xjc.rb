require "tmpdir"
require "cocaine"

module JAXB2Ruby
  class XJC  # :nodoc:
    CONFIG = File.join(File.dirname(__FILE__), "config.xjb")

    # https://github.com/thoughtbot/cocaine/issues/24
    Cocaine::CommandLine.runner = Cocaine::CommandLine::BackticksRunner.new

    def initialize(schema, options = {})
      @schema = schema
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
      line.run(:schema => @schema, :sources => @sources, :config => CONFIG)
    rescue Cocaine::ExitStatusError => e
      raise Error, "xjc execution failed: #{e}"
    rescue Cocaine::CommandNotFoundError => e
      raise command_not_found("xjc")
    end

    def javac
      files = Dir[ File.join(@sources, "**/*.java") ]
      line = Cocaine::CommandLine.new("javac", "-d :classes :files")
      line.run(:classes => @classes, :files => files)
    rescue Cocaine::ExitStatusError => e
      raise Error, "javac execution failed: #{e}"
    rescue Cocaine::CommandNotFoundError => e
      raise command_not_found("javac")
    end

    def command_not_found(cmd)
      Error.new("#{cmd} command not found, is it in your PATH enviornment variable?")
    end
  end
end
