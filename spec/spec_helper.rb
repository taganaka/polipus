# Require this file using `require "spec_helper"`
# to ensure that it is only loaded once.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
require 'digest/md5'
require 'coveralls'

require 'vcr'
require 'webmock/rspec'

Coveralls.wear!

VCR.configure do |c|
  c.cassette_library_dir = "#{File.dirname(__FILE__)}/cassettes"
  c.hook_into :webmock
end

require 'polipus'

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'
  config.mock_with :flexmock
  config.around(:each) do |example|
    t = Time.now
    print example.metadata[:full_description]
    VCR.use_cassette(Digest::MD5.hexdigest(example.metadata[:full_description])) do
      example.run
      puts " [#{Time.now - t}s]"
    end
  end
  config.before(:each) { Polipus::SignalHandler.disable }
end

def page_factory(url, params = {})
  Polipus::Page.new url, params
end
