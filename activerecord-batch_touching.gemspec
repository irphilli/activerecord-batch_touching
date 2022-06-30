# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'activerecord/batch_touching/version'

Gem::Specification.new do |spec|
  spec.name          = "activerecord-batch_touching"
  spec.version       = Activerecord::BatchTouching::VERSION
  spec.authors       = ["Brian Morearty", "Phil Phillips"]
  spec.email         = ["phil@productplan.com"]
  spec.summary       = %q{Batch up your ActiveRecord "touch" operations for better performance.}
  spec.description   = %q{Batch up your ActiveRecord "touch" operations for better performance. All accumulated "touch" calls will be consolidated into as few database round trips as possible.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency             "activerecord", ">= 6"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "simplecov-rcov"
  spec.add_development_dependency "yarjuf"
end
