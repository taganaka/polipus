require 'spec_helper'

describe Polipus::SignalHandler do
  context 'signal handler' do
    it 'should be enabled by default' do
      Polipus::PolipusCrawler.new('polipus-rspec', [])
      expect(Polipus::SignalHandler.enabled?).to be true
    end

    it 'should be disabled if specified' do
      Polipus::PolipusCrawler.new('polipus-rspec', [], enable_signal_handler: false)
      expect(Polipus::SignalHandler.enabled?).to be false
    end
  end
end
