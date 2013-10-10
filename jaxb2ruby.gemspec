$:.unshift File.expand_path("../lib/", __FILE__)

require "date"
require "jaxb2ruby"

Gem::Specification.new do |s|
  s.name        = "jaxb2ruby"
  s.version     = JAXB2Ruby::VERSION
  s.date        = Date.today
  s.summary     = "Generate Ruby objects from an XML schema using JAXB and JRuby"
  s.description =<<-DESC
    jaxb2ruby generates Java XML mappings via xjc, reads the resulting annotations, and passes the 
    extracted info to an ERB template. This allows one to automatically map an XML schema to pure 
    Ruby classes using the mapping framework of their choice. 
    
    Several templates are included: ROXML, HappyMapper and generic Ruby class.
  DESC
  s.authors     = ["Skye Shaw"]
  s.email       = "skye.shaw@gmail.com"
  s.executables  << "jaxb2ruby"

  #s.test_files  = Dir["spec/**/*.*"] 
  s.extra_rdoc_files = %w[README.rdoc]
  s.files       = Dir["lib/{templates/*.erb, xjc/*.xjb}"] + s.test_files + s.extra_rdoc_files
  s.homepage    = "http://github.com/sshaw/jaxb2ruby"
  s.license     = "MIT"
  s.add_dependency "activesupport", ">= 3.2"
  s.add_dependency "cocaine", "~> 0.5"
  s.add_development_dependency "rake", "~> 10.0"
end
