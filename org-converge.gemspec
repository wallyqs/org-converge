# -*- encoding: utf-8 -*-
require File.expand_path('../lib/org-converge/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Waldemar Quevedo"]
  gem.email         = ["waldemar.quevedo@gmail.com"]
  gem.description   = %q{A light configuration management tool for Org mode}
  gem.summary       = %q{Provides an 'org-converge' command which can be used for tangling and running Org mode code blocks}
  gem.homepage      = "https://github.com/wallyqs/org-converge"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "org-converge"
  gem.require_paths = ["lib"]
  gem.version       = OrgConverge::VERSION
  gem.license       = 'MIT'
  gem.add_runtime_dependency('docopt',   '~> 0.5')
  gem.add_runtime_dependency('org-ruby', '~> 0.9')
  gem.add_runtime_dependency('foreman',  '~> 0.63')
  gem.add_runtime_dependency('tco',      '~> 0.1')
  gem.add_runtime_dependency('rake',     '~> 10.3')
  gem.add_runtime_dependency('diff-lcs', '~> 1.2')
  gem.add_runtime_dependency('net-ssh', '~> 2.8')
  gem.add_runtime_dependency('net-scp', '~> 1.1')
end
