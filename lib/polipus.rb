# encoding: UTF-8
require "redis"
require "redis/connection/hiredis"
require "redis-queue"
require "polipus/version"
require "polipus/http"
require "polipus/storage"
require "polipus/url_tracker"
require "polipus/plugin"
require "polipus/queue_overflow"
require "thread"
require "logger"
require "json"
require "singleton"

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
      :logger => nil,
      # whether the query string should be included in the saved page
      :include_query_string_in_saved_page => true,
      # Max number of items to keep on redis
      :queue_items_limit => 2_000_000,
      # The adapter used to store exceed (queue_items_limit) redis items
      :queue_overflow_adapter => nil,
      # Every x seconds, the main queue is checked for overflowed items
      :queue_overflow_manager_check_time => 60,
      # If true, each page downloaded will increment a counter on redis
      :stats_enabled => false,
    }

    attr_reader :storage
    attr_reader :job_name
    attr_reader :logger
    attr_reader :overflow_adapter
    attr_reader :options
    attr_reader :crawler_name


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
      @logger       = @options[:logger] ||= Logger.new(nil)

      @storage      = @options[:storage]     ||= Storage.dev_null

      @http_pool    = []
      @workers_pool = []
      @queues_pool  = []
      
      
      @follow_links_like  = []
      @skip_links_like    = []
      @on_page_downloaded = []
      @on_before_save     = []
      @focus_crawl_block  = nil
      @redis_factory      = nil

      
      @overflow_manager = nil
      @crawler_name = `hostname`.strip + "-#{@job_name}"
      @redis = Redis.new(@options[:redis_options])
      @storage.include_query_string_in_uuid = @options[:include_query_string_in_saved_page]

      @urls = [urls].flatten.map{ |url| url.is_a?(URI) ? url : URI(url) }
      @urls.each{ |url| url.path = '/' if url.path.empty? }
      execute_plugin 'on_initialize'

      yield self if block_given?

    end

    def self.crawl(job_name, urls, opts = {})

      self.new(job_name, urls, opts) do |polipus|
        yield polipus if block_given?
        
        polipus.takeover
      end
      
    end

    def takeover
      PolipusSignalHandler.enable
      overflow_items_controller if queue_overflow_adapter

      q = queue_factory
      @urls.each do |u|
        next if url_tracker.visited?(u.to_s)
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

            unless should_be_visited?(page.url, false)
              @logger.info {"[worker ##{worker_number}] Page [#{page.url.to_s}] is no more welcome."}
              queue.commit
              next
            end

            if @storage.exists? page
              @logger.info {"[worker ##{worker_number}] Page [#{page.url.to_s}] already stored."}
              queue.commit
              next
            end
            
            url = page.url.to_s
            @logger.debug {"[worker ##{worker_number}] Fetching page: [#{page.url.to_s}] Referer: #{page.referer} Depth: #{page.depth}"}

            execute_plugin 'on_before_download'

            pages = http.fetch_pages(url, page.referer, page.depth)
            if pages.count > 1
              rurls = pages.map { |e| e.url.to_s }.join(' --> ')
              @logger.info {"Got redirects! #{rurls}"}
              page = pages.last
              if @storage.exists?(pages.last)
                @logger.info {"[worker ##{worker_number}] Page [#{page.url.to_s}] already stored."}
                queue.commit
                next
              end
            end
            page = pages.last
            
            # Execute on_before_save blocks
            @on_before_save.each {|e| e.call(page)} unless page.nil?
            execute_plugin 'on_after_download'
            
            @logger.warn {"Page #{page.url} has error: #{page.error}"} if page.error

            incr_error if page.error

            @storage.add page unless page.nil?
            
            @logger.debug {"[worker ##{worker_number}] Fetched page: [#{page.url.to_s}] Referer: [#{page.referer}] Depth: [#{page.depth}] Code: [#{page.code}] Response Time: [#{page.response_time}]"}
            @logger.info  {"[worker ##{worker_number}] Page [#{page.url.to_s}] downloaded"}
            
            incr_pages

            # Execute on_page_downloaded blocks
            @on_page_downloaded.each {|e| e.call(page)} unless page.nil?

            if @options[:depth_limit] == false || @options[:depth_limit] > page.depth 
              links_for(page).each do |url_to_visit|
                next unless should_be_visited?(url_to_visit)
                enqueue url_to_visit, page, queue
              end
            else
              @logger.info {"[worker ##{worker_number}] Depth limit reached #{page.depth}"}
            end

            @logger.debug {"[worker ##{worker_number}] Queue size: #{queue.size}"}
            @overflow_manager.perform if @overflow_manager && queue.empty?
            execute_plugin 'on_message_processed'

            if PolipusSignalHandler.terminated?
              @logger.info {"About to exit! Thanks for using Polipus"}
              queue.commit
              break
            end
            true
          end
        end
      end
      @workers_pool.each {|w| w.join}
      execute_plugin 'on_crawl_end'
    end
    
    # A pattern or an array of patterns can be passed as argument
    # An url will be discarded if it doesn't match patterns
    def follow_links_like(*patterns)
      @follow_links_like = @follow_links_like += patterns.uniq.compact
      self
    end

    # A pattern or an array of patterns can be passed as argument
    # An url will be discarded if it matches a pattern
    def skip_links_like(*patterns)
      @skip_links_like = @skip_links_like += patterns.uniq.compact
      self
    end

    # A block of code will be executed on every page dowloaded
    # The block takes the page as argument
    def on_page_downloaded(&block)
      @on_page_downloaded << block
      self
    end

    # A block of code will be executed on every page donloaded
    # before being saved in the registered storage
    def on_before_save(&block)
      @on_before_save << block
      self
    end

    def focus_crawl(&block)
      @focus_crawl_block = block
      self
    end

    def redis_options
      @options[:redis_options]
    end

    def overflow_adapter
      @options[:overflow_adapter]
    end

    def queue_size
      @internal_queue ||= queue_factory
      @internal_queue.size
    end

    def stats_reset!
      ["polipus:#{@job_name}:errors", "polipus:#{@job_name}:pages"].each {|e| @redis.del i}
    end

    def redis_factory(&block)
      @redis_factory = block
      self
    end

    def url_tracker
      if @url_tracker.nil?
        @url_tracker  = @options[:url_tracker] ||= UrlTracker.bloomfilter(:key_name => "polipus_bf_#{job_name}", :redis => redis_factory_adapter, :driver => 'lua')
      end
      @url_tracker
    end

    def redis
      if @redis.nil?
        @redis = redis_factory_adapter
      end
      @redis
    end

    # Request to Polipus to stop its work (gracefully)
    # cler_queue = true if you want to delete all of the pending urls to visit
    def stop!(cler_queue = false)
      PolipusSignalHandler.terminate
      queue_factory.clear(true) if cler_queue
    end

    private
      # URLs enqueue policy
      def should_be_visited?(url, with_tracker = true)

        # Check against whitelist pattern matching
        unless @follow_links_like.empty?
          return false unless @follow_links_like.any?{|p| url.path =~ p}  
        end

        # Check against blacklist pattern matching
        unless @skip_links_like.empty?
          return false if @skip_links_like.any?{|p| url.path =~ p}
        end

        # Check against url tracker
        if with_tracker
          return false if  url_tracker.visited?(@options[:include_query_string_in_saved_page] ? url.to_s : url.to_s.gsub(/\?.*$/,''))
        end
        true
      end

      # It extracts URLs from the page
      def links_for page
        links = @focus_crawl_block.nil? ? page.links : @focus_crawl_block.call(page)
        links
      end

      # The url is enqueued for a later visit
      def enqueue url_to_visit, current_page, queue
        page_to_visit = Page.new(url_to_visit.to_s, :referer => current_page.url.to_s, :depth => current_page.depth + 1)
        queue << page_to_visit.to_json
        to_track = @options[:include_query_string_in_saved_page] ? url_to_visit.to_s : url_to_visit.to_s.gsub(/\?.*$/,'')
        url_tracker.visit to_track
        @logger.debug {"Added [#{url_to_visit.to_s}] to the queue"}        
      end

      # It creates a redis client
      def redis_factory_adapter
        unless @redis_factory.nil?
          return @redis_factory.call(redis_options)
        end
        Redis.new(redis_options)
      end

      # It creates a new distributed queue
      def queue_factory
        Redis::Queue.new("polipus_queue_#{@job_name}","bp_polipus_queue_#{@job_name}", :redis => redis_factory_adapter)
      end

      # If stats enable, it increments errors found
      def incr_error
        @redis.incr "polipus:#{@job_name}:errors" if @options[:stats_enabled]
      end

      # If stats enable, it increments pages downloaded
      def incr_pages
        @redis.incr "polipus:#{@job_name}:pages" if @options[:stats_enabled]
      end

      # It handles the overflow item policy (if any)
      def overflow_items_controller
        @overflow_manager = QueueOverflow::Manager.new(self, queue_factory, @options[:queue_items_limit])

        # In the time, url policy may change so policy is re-evaluated
        @overflow_manager.url_filter do |page|
          should_be_visited?(page.url, false)
        end

        Thread.new do
         
          redis_lock = redis_factory_adapter
          op_timeout = @options[:queue_overflow_manager_check_time]

          while true
            lock = redis_lock.setnx "polipus_queue_overflow-#{@job_name}.lock", 1

            if lock
              redis_lock.expire "polipus_queue_overflow-#{@job_name}.lock", op_timeout + 350
              removed, restored = @overflow_manager.perform
              @logger.info {"Overflow Manager: items removed=#{removed}, items restored=#{restored}, items stored=#{queue_overflow_adapter.size}"}
              redis_lock.del "polipus_queue_overflow-#{@job_name}.lock"
            else
              @logger.info {"Lock not acquired"}
            end

            sleep @options[:queue_overflow_manager_check_time]
          end
        end
      end

      # It invokes a plugin method if any
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

  class PolipusSignalHandler
    include Singleton
    attr_accessor :terminated
    def initialize
      self.terminated = false
    end

    def self.enable
      trap(:INT)  {
        puts "Got INT signal"
        self.terminate
      }
      trap(:TERM) {
        puts "Got TERM signal"
        self.terminate
      }
    end

    def self.terminate
      self.instance.terminated = true
    end

    def self.terminated?
      self.instance.terminated
    end
  end

end
