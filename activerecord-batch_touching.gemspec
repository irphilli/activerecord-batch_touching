# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "activerecord/batch_touching/version"

Gem::Specification.new do |spec|
  spec.name          = "activerecord-batch_touching"
  spec.version       = Activerecord::BatchTouching::VERSION
  spec.authors       = ["Brian Morearty", "Phil Phillips"]
  spec.email         = ["phil@productplan.com"]
  spec.summary       = 'Batch up your ActiveRecord "touch" operations for better performance.'
  spec.description   = 'Batch up your ActiveRecord "touch" operations for better performance. All accumulated "touch" calls will be consolidated into as few database round trips as possible.'
  spec.homepage      = "https://github.com/ProductPlan/activerecord-batch_touching"
  spec.license       = "MIT"

  spec.files         = Dir["LICENSE", "README", "lib/**/*"]
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency             "activerecord", ">= 6"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-performance"
  spec.add_development_dependency "rubocop-rake"
  spec.add_development_dependency "rubocop-rspec"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "simplecov-rcov"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "timecop"

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.required_ruby_version = ">= 3.0.0"
end
