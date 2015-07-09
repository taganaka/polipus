# encoding: UTF-8
require 'spec_helper'

describe Polipus::PolipusCrawler do
  after(:each) { Redis.new(db: 10).flushdb }
  let(:p_options) do
    {
      workers: 1,
      redis_options: { host: 'localhost', db: 10 },
      depth_limit: 1,
      queue_timeout: 1,
      user_agent: 'polipus-rspec',
      logger: logger,
      logger_level: Logger::DEBUG,
      storage: Polipus::Storage.memory_store
    }
  end
  let(:polipus) do
    Polipus::PolipusCrawler.new('polipus-rspec', ['http://rubygems.org/gems'], p_options)
  end

  let(:init_page)do
    Polipus::Page.new 'http://rubygems.org/gems'
  end

  let(:logger) { Logger.new(nil) }

  context 'polipus' do
    it 'should create a polipus instance' do
      expect(polipus).to be_an_instance_of Polipus::PolipusCrawler
    end

    it 'should execute a crawling session' do
      polipus.takeover
      expect(polipus.storage.exists?(init_page)).to be_truthy
      expect(polipus.storage.get(init_page).links.count).to be polipus.storage.count
    end

    it 'should filter unwanted urls' do
      polipus.skip_links_like(/\/pages\//)
      polipus.takeover
      expect(polipus.storage.get(init_page).links
        .reject { |e| e.path.to_s =~ /\/pages\// }.count).to be polipus.storage.count
    end

    it 'should follow only wanted urls' do
      polipus.follow_links_like(/\/pages\//)
      polipus.follow_links_like(/\/gems$/)
      polipus.takeover
      expect(polipus.storage.get(init_page).links
        .reject { |e| ![/\/pages\//, /\/gems$/].any? { |p| e.path =~ p } }
        .count).to be polipus.storage.count
    end

    it 'should refresh expired pages' do
      polipus.ttl_page = 3600
      polipus.takeover
      polipus.storage.each do |_id, page|
        page.fetched_at = page.fetched_at - 3600
        polipus.storage.add(page)
      end
      polipus.storage.each { |_id, page| expect(page.expired?(3600)).to be_truthy }
      polipus.takeover
      polipus.storage.each { |_id, page| expect(page.expired?(3600)).to be_falsey }
    end

    it 'should re-download seeder urls no matter what' do
      cache_hit = {}
      polipus.follow_links_like(/\/gems$/)
      polipus.on_page_downloaded do |page|
        cache_hit[page.url.to_s] ||= 0
        cache_hit[page.url.to_s] += 1
      end
      polipus.takeover
      polipus.takeover
      expect(cache_hit['http://rubygems.org/gems']).to be 2
    end

    it 'should call on_page_error code blocks when a page has error' do
      p = Polipus::PolipusCrawler.new('polipus-rspec', ['http://dasd.adad.dom/'], p_options.merge(open_timeout: 1, read_timeout: 1))
      a_page = nil
      p.on_page_error { |page| a_page = page }
      p.takeover
      expect(a_page).not_to be_nil
      expect(a_page.error).not_to be_nil
    end

    it 'should obey to the robots.txt file' do
      lopt = p_options
      lopt[:obey_robots_txt] = true
      polipus = Polipus::PolipusCrawler.new('polipus-rspec', ['https://rubygems.org/gems/polipus'], lopt)
      polipus.depth_limit = 1
      polipus.takeover
      polipus.storage.each { |_id, page| expect(page.url.path =~ /$\/downloads\//).to be_falsey }
    end

    it 'should obey to the robots.txt file with list user_agent' do
      user_agent = 'Mozilla/5.0 (Windows; U; Windows NT 5.1; tr; rv:1.9.2.8) Gecko/20100722 Firefox/3.6.8 ( .NET CLR 3.5.30729; .NET4.0E)'
      lopt = p_options
      lopt[:obey_robots_txt] = true
      lopt[:user_agent] = [user_agent]
      flexmock(Polipus::Robotex).should_receive(:new).with(user_agent)
      Polipus::PolipusCrawler.new('polipus-rspec', ['https://rubygems.org/gems/polipus'], lopt)
    end
  end
end
