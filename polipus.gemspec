# -*- encoding: utf-8 -*-
$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'polipus/version'

Gem::Specification.new do |s|
  s.name        = 'polipus'
  s.version     = Polipus::VERSION
  s.authors     = ['Francesco Laurita']
  s.email       = ['francesco.laurita@gmail.com']
  s.homepage    = Polipus::HOMEPAGE
  s.summary     = %q(Polipus distributed web-crawler framework)
  s.description = %q(
    An easy to use distributed web-crawler framework based on Redis
  )
  s.licenses    = ['MIT']

  s.rubyforge_project = 'polipus'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_runtime_dependency 'redis-bloomfilter', '~> 0.0', '>= 0.0.3'
  s.add_runtime_dependency 'redis-queue', '~> 0.0', '>= 0.0.4'
  s.add_runtime_dependency 'nokogiri', '~> 1.6', '>= 1.6.0'
  s.add_runtime_dependency 'hiredis', '~> 0.4', '>= 0.4.5'
  s.add_runtime_dependency 'redis', '~> 3.0', '>= 3.0.4'
  s.add_runtime_dependency 'mongo', '~> 1.9.0', '>= 1.9.2'

  if defined?(JRUBY_VERSION)
    s.add_runtime_dependency 'bson', '~> 1.9', '>= 1.9.2'
  else
    s.add_runtime_dependency 'bson_ext', '~> 1.9', '>= 1.9.2'
  end
  s.add_runtime_dependency 'aws-s3', '~> 0.6', '>= 0.6.3'
  s.add_runtime_dependency 'http-cookie', '~> 1.0', '>= 1.0.1'

  s.add_development_dependency 'rspec', '~> 2.14', '>= 2.14.1'
  s.add_development_dependency 'vcr', '~> 2.5', '>= 2.5.0'
  s.add_development_dependency 'webmock', '>= 1.8.0', '< 1.12'
  s.add_development_dependency 'flexmock', '~> 1.3', '>= 1.3.2'
  s.add_development_dependency 'rake', '~> 10.3', '>= 10.3.2'
  s.add_development_dependency 'coveralls'

end
