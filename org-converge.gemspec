# -*- encoding: utf-8 -*-
require File.expand_path('../lib/org-converge/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Waldemar Quevedo"]
  gem.email         = ["waldemar.quevedo@gmail.com"]
  gem.description   = %q{A light configuration management tool for Org mode}
  gem.homepage      = "https://github.com/wallyqs/org-converge"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "org-converge"
  gem.require_paths = ["lib"]
  gem.version       = OrgConverge::VERSION
end
