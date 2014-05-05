require "spec_helper"

describe Polipus::PolipusCrawler do
  after(:each) {Redis.new(db:10).flushdb}
  let(:p_options) {
    {
      workers: 1,
      redis_options: {host: 'localhost', db:10},
      depth_limit: 1,
      logger: logger,
      queue_timeout: 1,
      user_agent: 'polipus-rspec',
      storage: Polipus::Storage.memory_store
    }
  }
  let(:polipus) {
    Polipus::PolipusCrawler.new("polipus-rspec", ["http://rubygems.org/gems"], p_options)
  }

  let(:logger){Logger.new(STDOUT)}

  context "polipus" do
    it "should create a polipus instance" do
      polipus.should be_an_instance_of Polipus::PolipusCrawler
    end

    it "should execute a crawling session" do
      polipus.takeover
      init_page = Polipus::Page.new "http://rubygems.org/gems"
      polipus.storage.exists?(init_page).should be_true
      polipus.storage.get(init_page).links.count.should be polipus.storage.count
    end


  end
end