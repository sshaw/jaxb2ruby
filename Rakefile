require "rake/testtask"

task :default => "test"
Rake::TestTask.new do |t|
  t.ruby_opts << "--ng"
  t.test_files = FileList["spec/*_spec.rb"]
  t.verbose = true
end
