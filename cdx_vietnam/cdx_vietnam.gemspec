$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "cdx_vietnam/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "cdx_vietnam"
  s.version     = CdxVietnam::VERSION
  s.authors     = ["Jorge Alvarez"]
  s.email       = ["jorge@alvareznavarro.es"]
  s.homepage    = "http://www.thecdx.org"
  s.summary     = "Custom settings for Vietnam"
  s.description = "Customisation and localising of the vietnamese version of CDX."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.7.1"
end
