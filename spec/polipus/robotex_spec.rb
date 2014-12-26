# encoding: UTF-8
require 'spec_helper'
require 'polipus/robotex'
describe Polipus::Robotex do
  let(:spec_domain) { 'http://www.example.com/' }
  before(:each) do
    robots = <<-END
User-Agent: msnbot
Crawl-Delay: 20

User-Agent: bender
Disallow: /my_shiny_metal_ass

User-Agent: *
Disallow: /login
Allow: /

Disallow: /locked
Allow: /locked
END
    stub_request(:get, 'http://www.example.com/robots.txt')
    .to_return(body: robots, status: [200, 'OK'], headers: { 'Content-Type' => 'text/plain' })
  end

  describe '#initialize' do
    context 'when no arguments are supplied' do
      it 'returns a Robotex with the default user-agent' do
        expect(Polipus::Robotex.new.user_agent).to eq("Robotex/#{Polipus::Robotex::VERSION} (http://www.github.com/chriskite/robotex)")
      end
    end

    context 'when a user-agent is specified' do
      it 'returns a Robotex with the specified user-agent' do
        ua = 'My User Agent'
        expect(Polipus::Robotex.new(ua).user_agent).to eq(ua)
      end
    end
  end

  describe '#allowed?' do
    context 'when the robots.txt disallows the user-agent to the url' do
      it 'returns false' do
        robotex = Polipus::Robotex.new('bender')
        expect(robotex.allowed?(spec_domain + 'my_shiny_metal_ass')).to be_falsey
      end
    end

    context 'when the robots.txt disallows the user-agent to some urls, but allows this one' do
      it 'returns true' do
        robotex = Polipus::Robotex.new('bender')
        expect(robotex.allowed?(spec_domain + 'cigars')).to be_truthy
      end
    end

    context 'when the robots.txt disallows any user-agent to the url' do
      it 'returns false' do
        robotex = Polipus::Robotex.new
        expect(robotex.allowed?(spec_domain + 'login')).to be_falsey
      end
    end

    context 'when the robots.txt disallows and then allows the url' do
      it 'returns false' do
        robotex = Polipus::Robotex.new
        expect(robotex.allowed?(spec_domain + 'locked')).to be_falsey
      end
    end
  end

  describe '#delay' do
    context 'when no Crawl-Delay is specified for the user-agent' do
      it 'returns nil' do
        robotex = Polipus::Robotex.new
        expect(robotex.delay(spec_domain)).to be_nil
      end

      context 'when Crawl-Delay is specified for the user-agent' do
        it 'returns the delay as a Fixnum' do
          robotex = Polipus::Robotex.new('msnbot')
          expect(robotex.delay(spec_domain)).to eq(20)
        end
      end
    end
  end

end
