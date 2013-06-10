require "redis"
require "redis/connection/hiredis"
require "redis-queue"
require "polipus/version"
require "polipus/http"
require "polipus/storage"
require "polipus/url_tracker"
require "polipus/plugin"
require "logger"
require "json"

module Polipus
  
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
      :read_timeout => 30,
      # An URL tracker instance. default is Bloomfilter based on redis
      :url_tracker => nil,
      # A Redis options {} that will be passed directly to Redis.new
      :redis_options => {},
      # An instance of logger
      :logger => nil
    }

    OPTS.keys.each do |key|
      define_method "#{key}=" do |value|
        @options[key.to_sym] = value
      end
      define_method "#{key}" do
        @options[key.to_sym]
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
      @logger       = @options[:logger] ||= Logger.new(nil)
      @follow_links_like = []
      @skip_links_like   = []
      @on_page_downloaded = []

      @urls.each{ |url| url.path = '/' if url.path.empty? }

      execute_plugin 'on_initialize'
      yield self if block_given?
    end

    def takeover
      q = queue_factory
      @urls.each do |u|
        next if @url_tracker.visited?(u.to_s)
        q << Page.new(u.to_s, :referer => '').to_json
      end

      return if q.empty?

      execute_plugin 'on_crawl_start'
      @options[:workers].times do |worker_number|
        @workers_pool << Thread.new do
          @logger.debug {"Start worker #{worker_number}"}
          http  = @http_pool[worker_number]   ||= HTTP.new(@options)
          queue = @queues_pool[worker_number] ||= queue_factory
          queue.process(false, @options[:read_timeout]) do |message|

            next if message.nil?

            execute_plugin 'on_message_received'

            page = Page.from_json message
            url = page.url.to_s
            @logger.info {"[worker ##{worker_number}] Fetching page: {#{page.url.to_s}] Referer: #{page.referer} Depth: #{page.depth}"}

            execute_plugin 'on_before_download'
            page = http.fetch_page(url, page.referer, page.depth)
            execute_plugin 'on_after_download'

            @storage.add page
            @logger.info {"[worker ##{worker_number}] Fetched page: {#{page.url.to_s}] Referer: #{page.referer} Depth: #{page.depth} Code: #{page.code} Response Time: #{page.response_time}"}

            # Execute on_page_downloaded blocks
            @on_page_downloaded.each {|e| e.call(page)}

            if @options[:depth_limit] == false || @options[:depth_limit] > page.depth 
              page.links.each do |url_to_visit|
                next unless should_be_visited?(url_to_visit)
                enqueue url_to_visit, page, queue
              end
            else
              @logger.info {"[worker ##{worker_number}] Depth limit reached #{page.depth}"}
            end

            @logger.info {"[worker ##{worker_number}] Queue size: #{queue.size}"}
            execute_plugin 'on_message_processed'
            true
          end
        end
      end
      @workers_pool.each {|w| w.join}
      execute_plugin 'on_crawl_end'
    end
  
    def follow_links_like(*patterns)
      @follow_links_like = @follow_links_like += patterns.uniq.compact
      self
    end

    def skip_links_like(*patterns)
      @skip_links_like = @skip_links_like += patterns.uniq.compact
      self
    end

    def on_page_downloaded(&block)
      @on_page_downloaded << block
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

      def execute_plugin method
        Polipus::Plugin.plugins.each do |k,p|
          if p.respond_to? method
            @logger.info("Running plugin method #{method} on #{k}")
            ret_val = p.send(method, self)
            instance_eval(&ret_val) if ret_val.kind_of? Proc
          end
        end
      end
  
  end
end
