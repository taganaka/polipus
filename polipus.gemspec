# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "polipus/version"

Gem::Specification.new do |s|
  s.name        = "polipus"
  s.version     = Polipus::VERSION
  s.authors     = ["Francesco Laurita"]
  s.email       = ["francesco.laurita@gmail.com"]
  s.homepage    = "https://github.com/taganaka/polipus"
  s.summary     = %q{Polipus distributed web-crawler framework}
  s.description = %q{
    An easy to use distrubuted web-crawler framework based on redis
  }

  s.rubyforge_project = "polipus"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "redis-bloomfilter", "~> 0.0.1"
  s.add_dependency "redis-queue",       "~> 0.0.3"
  s.add_dependency "nokogiri",          "~> 1.6.0"
  s.add_dependency "hiredis",           "~> 0.4.5"
  s.add_dependency "redis",             "~> 3.0.4"
  s.add_dependency "mongo",             "~> 1.8.6"
  s.add_dependency "bson_ext",          "~> 1.8.6"
  s.add_dependency "json",              "~> 1.8.0"
  s.add_development_dependency "rspec"
  s.add_development_dependency "vcr", "~> 2.5.0"
  s.add_development_dependency "webmock"
end
