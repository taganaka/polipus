require "redis-queue"
require "polipus/version"
require "polipus/http"
require "polipus/storage"
require "polipus/url_tracker"
require "logger"
require "json"

trap(:INT) { exit } #I hate ctrl+c's error
module Polipus
  
  # @@queue.clear(true)
  # @@url_tracker.clear
  # @@storage.clear
  #http://annunci.ebay.it/annunci/auto/novara-annunci-novara/lancia-k-diesel-come-nuova/45834766
  #http://annunci.ebay.it/motori/auto/?p=2
  #@@focus_on = /^\/wordpress\//i
  def Polipus.crawler(job_name = 'polipus', urls = [], options = {}, &block)
    PolipusCrawler.crawl(job_name, urls, options, &block)
  end

  class PolipusCrawler
    OPTS = {
      # run 4 threads
      :workers => 4,
      # identify self as Anemone/VERSION
      :user_agent => "Polipus - #{Polipus::VERSION} - #{Polipus::HOMEPAGE}",
      # by default, don't limit the depth of the crawl
      :depth_limit => false,
      # number of times HTTP redirects will be followed
      :redirect_limit => 5,
      # storage engine defaults to DevNull 
      :storage => nil,
      # proxy server hostname 
      :proxy_host => nil,
      # proxy server port number
      :proxy_port => false,
      # HTTP read timeout in seconds
      :read_timeout => nil,
      # An URL tracker instance. default is Bloomfilter based on redis
      :url_tracker => nil,
      # A Redis options {} that will be passed directly to Redis.new
      :redis_options => {},
      # An instance of logger
      :logger => nil,
      # Reset the current work: Dangerous!
      :reset => false,
    }

    OPTS.keys.each do |key|
      define_method "#{key}=" do |value|
        @options[key.to_sym] = value
      end
    end

    def initialize(job_name = 'polipus',urls = [], options = {})

      @job_name     = job_name
      @options      = OPTS.merge(options)
      @storage      = @options[:storage]     ||= Storage.dev_null
      @url_tracker  = @options[:url_tracker] ||= UrlTracker.bloomfilter(:key_name => "polipus_bf_#{job_name}", :redis => Redis.new(@options[:redis_options]))
      @http_pool    = []
      @workers_pool = []
      @queues_pool  = []
      @urls         = [urls].flatten.map{ |url| url.is_a?(URI) ? url : URI(url) }
      @logger       = @options[:logger] ||= Logger.new(STDOUT)
      @follow_links_like = []
      @skip_links_like   = []

      @urls.each{ |url| url.path = '/' if url.path.empty? }

      if @options[:reset]
        puts "reset"
        @url_tracker.clear
        @storage.clear
        queue_factory.clear
      end

      yield self if block_given?
    end

    def takeover
      q = queue_factory
      @urls.each do |u|
        next if @url_tracker.visited?(u.to_s)
        q << Page.new(u.to_s, :referer => '').to_json
      end

      return if q.empty?

      @options[:workers].times do |worker_number|
        @workers_pool << Thread.new do
          @logger.info {"Start worker #{worker_number}"}
          http  = @http_pool[worker_number]   ||= HTTP.new(@options)
          queue = @queues_pool[worker_number] ||= queue_factory
          queue.process do |message|

            next if message.nil?

            page = Page.from_json message
            url = page.url.to_s
            @logger.info {"[worker ##{worker_number}] Fetching page: {#{page.url.to_s}] Referer: #{page.referer} Depth: #{page.depth}"}
            page = http.fetch_page(url, page.referer, page.depth)
            @storage.add page

            page.links.each do |url_to_visit|
              next unless should_be_visited?(url_to_visit)
              enqueue url_to_visit, page, queue
            end

            @logger.debug {"Queue size: #{queue.size}"}
            true
          end
        end
        #sleep 10 if worker_number == 0
      end
      @workers_pool.each {|w| w.join}
    end
  
    def follow_links_like(*patterns)
      @follow_links_like = @follow_links_like += patterns.uniq.compact
      self
    end

    def skip_links_like(*patterns)
      @skip_links_like = @skip_links_like += patterns.uniq.compact
      self
    end

    def self.crawl(job_name, urls, opts = {})

      self.new(job_name, urls, opts) do |polipus|
        yield polipus if block_given?
        polipus.takeover
      end
    end

    private
      def should_be_visited?(url)

        return false unless @follow_links_like.any?{|p| url.path =~ p}
        return false if     @skip_links_like.any?{|p| url.path =~ p}
        return false if     @url_tracker.visited?(url.to_s)
        true
      end

      def enqueue url_to_visit, current_page, queue
        page_to_visit = Page.new(url_to_visit.to_s, :referer => current_page.url.to_s, :depth => current_page.depth + 1)
        queue << page_to_visit.to_json
        @url_tracker.visit url_to_visit.to_s
        @logger.debug {"Added [#{url_to_visit.to_s}] to the queue"}
      end

      def queue_factory
        Redis::Queue.new("polipus_queue_#{@job_name}","bp_polipus_queue_#{@job_name}", :redis => Redis.new(@options[:redis_options]))
      end
  
  end
end
