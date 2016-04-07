require "rake/testtask"

task :default => "test"
Rake::TestTask.new do |t|
  t.libs << "spec"
  t.test_files = FileList["spec/*_spec.rb"]
  t.verbose = true
end

task :xjc do
  schema = ENV["SCHEMA"]
  abort "SCHEMA not set" if schema.to_s.strip.empty?

  output = ENV["OUTPUT"] || "java-src"
  FileUtils.mkdir(output) unless File.directory?(output)

  sh "xjc -extension -npa -d #{output} #{schema} -b lib/jaxb2ruby/config.xjb"
end
