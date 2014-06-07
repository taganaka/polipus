require 'spec_helper'

describe Polipus::SignalHandler do

  context 'signal handler' do

    it 'should be enabled by default' do
      Polipus::PolipusCrawler.new('polipus-rspec', [])
      Polipus::SignalHandler.enabled?.should be true
    end

    it 'should be disabled if specified' do
      Polipus::PolipusCrawler.new('polipus-rspec', [], enable_signal_handler: false)
      Polipus::SignalHandler.enabled?.should be false
    end

  end
end
