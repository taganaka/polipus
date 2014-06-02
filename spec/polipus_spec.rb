require "spec_helper"

describe Polipus::PolipusCrawler do
  after(:each) {Redis.new(db:10).flushdb}
  let(:p_options) {
    {
      workers: 1,
      redis_options: {host: 'localhost', db:10},
      depth_limit: 1,
      queue_timeout: 1,
      user_agent: 'polipus-rspec',
      logger: logger,
      logger_level: Logger::DEBUG,
      storage: Polipus::Storage.memory_store
    }
  }
  let(:polipus) {
    Polipus::PolipusCrawler.new("polipus-rspec", ["http://rubygems.org/gems"], p_options)
  }

  let(:init_page){
    Polipus::Page.new "http://rubygems.org/gems"
  }

  let(:logger){Logger.new(nil)}

  context "polipus" do

    it "should create a polipus instance" do
      polipus.should be_an_instance_of Polipus::PolipusCrawler
    end

    it "should execute a crawling session" do
      polipus.takeover
      polipus.storage.exists?(init_page).should be_true
      polipus.storage.get(init_page).links.count.should be polipus.storage.count
    end

    it "should filter unwanted urls" do
      polipus.skip_links_like(/\/pages\//)
      polipus.takeover
      polipus.storage.get(init_page).links
        .reject { |e| e.path.to_s =~ /\/pages\// }.count.should be polipus.storage.count
    end

    it "should follow only wanted urls" do
      polipus.follow_links_like(/\/pages\//)
      polipus.follow_links_like(/\/gems$/)
      polipus.takeover
      polipus.storage.get(init_page).links
        .reject { |e| ![/\/pages\//, /\/gems$/].any?{|p| e.path =~ p} }
        .count.should be polipus.storage.count
    end

    it "should refresh expired pages" do
      polipus.ttl_page = 3600
      polipus.takeover
      polipus.storage.each {|id, page| page.fetched_at = page.fetched_at - 3600; polipus.storage.add(page)}
      polipus.storage.each {|id, page| page.expired?(3600).should be_true}
      polipus.takeover
      polipus.storage.each {|id, page| page.expired?(3600).should be_false}
    end

    it "should re-download seeder urls no matter what" do
      cache_hit = {}
      polipus.follow_links_like(/\/gems$/)
      polipus.on_page_downloaded do |page|
        cache_hit[page.url.to_s] ||= 0
        cache_hit[page.url.to_s] += 1
      end
      polipus.takeover
      polipus.takeover
      cache_hit["http://rubygems.org/gems"].should be 2
    end

    it "should call on_page_error code blocks when a page has error" do
      p = Polipus::PolipusCrawler.new("polipus-rspec", ["http://dasd.adad.dom/"], p_options.merge(open_timeout:1, read_timeout: 1))
      a_page = nil
      p.on_page_error {|page| a_page = page}
      p.takeover
      a_page.should_not be_nil
      a_page.error.should_not be_nil
    end

    it "should obey to the robots.txt file" do
      lopt = p_options
      lopt[:obey_robots_txt] = true
      polipus = Polipus::PolipusCrawler.new("polipus-rspec", ["https://rubygems.org/gems/polipus"], lopt)
      polipus.depth_limit = 1
      polipus.takeover
      polipus.storage.each {|id, page| (page.url.path =~ /$\/downloads\//).should be_false}
    end

  end
end