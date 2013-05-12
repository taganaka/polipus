# encoding: utf-8

require 'rubygems'
require 'bundler'
require './lib/polipus/version'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "polipus"
  gem.homepage = "http://github.com/taganaka/polipus"
  gem.license = "MIT"
  gem.summary = %Q{Polipus distributed web-crawler framework}
  gem.description = %Q{An easy to use distrubuted web-crawler framework based on redis}
  gem.email = "francesco.laurita@gmail.com"
  gem.authors = ["Francesco Laurita"]
  gem.version = Polipus::VERSION
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "polipus #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
