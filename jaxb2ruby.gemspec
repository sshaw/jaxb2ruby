require "date"

Gem::Specification.new do |s|
  s.name        = "jaxb2ruby"
  s.version     = "v0.0.1"
  s.date        = Date.today
  s.summary     = "Generate XML object mappings from a schema using JAXB"
  s.description =<<-DESC
  DESC
  s.authors     = ["Skye Shaw"]
  s.email       = "skye.shaw@gmail.com"
  s.executables  << "jaxb2ruby"

  #s.test_files  = Dir["spec/**/*.*"] 
  s.extra_rdoc_files = %w[README.rdoc]
  s.files       = Dir["lib/{templates/*.erb,xjc/*.xjb}"] + s.test_files + s.extra_rdoc_files
  s.homepage    = "http://github.com/sshaw/jaxb2ruby"
  s.license     = "MIT"
  s.add_dependency "activesupport", ">= 3.2"
end
