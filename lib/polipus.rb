# encoding: UTF-8
require 'redis'
require 'redis/connection/hiredis'
require 'redis-queue'
require 'polipus/version'
require 'polipus/http'
require 'polipus/storage'
require 'polipus/url_tracker'
require 'polipus/plugin'
require 'polipus/queue_overflow'
require 'polipus/robotex'
require 'polipus/signal_handler'
require 'thread'
require 'logger'
require 'json'

module Polipus
  def self.crawler(job_name = 'polipus', urls = [], options = {}, &block)
    PolipusCrawler.crawl(job_name, urls, options, &block)
  end

  class PolipusCrawler
    OPTS = {
      # run 4 threads
      workers: 4,
      # identify self as Polipus/VERSION
      user_agent: "Polipus - #{Polipus::VERSION} - #{Polipus::HOMEPAGE}",
      # by default, don't limit the depth of the crawl
      depth_limit: false,
      # number of times HTTP redirects will be followed
      redirect_limit: 5,
      # storage engine defaults to DevNull
      storage: nil,
      # proxy server hostname
      proxy_host: nil,
      # proxy server port number
      proxy_port: false,
      # proxy server username
      proxy_user: nil,
      # proxy server password
      proxy_pass: nil,
      # HTTP read timeout in seconds
      read_timeout: 30,
      # HTTP open connection timeout in seconds
      open_timeout: 10,
      # Time to wait for new messages on Redis
      # After this timeout, current crawling session is marked as terminated
      queue_timeout: 30,
      # An URL tracker instance. default is Bloomfilter based on redis
      url_tracker: nil,
      # A Redis options {} that will be passed directly to Redis.new
      redis_options: {},
      # An instance of logger
      logger: nil,
      # A logger level
      logger_level: nil,
      # whether the query string should be included in the saved page
      include_query_string_in_saved_page: true,
      # Max number of items to keep on redis
      queue_items_limit: 2_000_000,
      # The adapter used to store exceed (queue_items_limit) redis items
      queue_overflow_adapter: nil,
      # Every x seconds, the main queue is checked for overflowed items
      queue_overflow_manager_check_time: 60,
      # If true, each page downloaded will increment a counter on redis
      stats_enabled: false,
      # Cookies strategy
      cookie_jar: nil,
      # whether or not accept cookies
      accept_cookies: false,
      # A set of hosts that should be considered parts of the same domain
      # Eg It can be used to follow links with and without 'www' domain
      domain_aliases: [],
      # Mark a connection as staled after connection_max_hits request
      connection_max_hits: nil,
      # Page TTL: mark a page as expired after ttl_page seconds
      ttl_page: nil,
      # don't obey the robots exclusion protocol
      obey_robots_txt: false,
      # If true, signal handling strategy is enabled.
      # INT and TERM signal will stop polipus gracefully
      # Disable it if polipus will run as a part of Resque or DelayedJob-like system
      enable_signal_handler: true
    }

    attr_reader :storage
    attr_reader :job_name
    attr_reader :logger
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

    def initialize(job_name = 'polipus', urls = [], options = {})
      @job_name     = job_name
      @options      = OPTS.merge(options)
      @options[:queue_timeout] = 1 if @options[:queue_timeout] <= 0
      @logger       = @options[:logger]  ||= Logger.new(nil)

      unless @logger.class.to_s == 'Log4r::Logger'
        @logger.level = @options[:logger_level] ||= Logger::INFO
      end

      @storage      = @options[:storage] ||= Storage.dev_null

      @workers_pool = []

      @follow_links_like  = []
      @skip_links_like    = []
      @on_page_downloaded = []
      @on_before_save     = []
      @on_page_error      = []
      @focus_crawl_block  = nil
      @on_crawl_start     = []
      @on_crawl_end       = []
      @redis_factory      = nil

      @overflow_manager = nil
      @crawler_name = `hostname`.strip + "-#{@job_name}"

      @storage.include_query_string_in_uuid = @options[:include_query_string_in_saved_page]

      @urls = [urls].flatten.map { |url| URI(url) }
      @urls.each { |url| url.path = '/' if url.path.empty? }
      if @options[:obey_robots_txt]
        @robots =
          if @options[:user_agent].respond_to?(:sample)
            Polipus::Robotex.new(@options[:user_agent].sample)
          else
            Polipus::Robotex.new(@options[:user_agent])
          end
      end
      # Attach signal handling if enabled
      SignalHandler.enable if @options[:enable_signal_handler]

      if queue_overflow_adapter
        @on_crawl_start << lambda do |_|
          Thread.new do
            Thread.current[:name] = :overflow_items_controller
            overflow_items_controller.run
          end
        end
      end

      @on_crawl_end << lambda do |_|
        Thread.list.select { |thread| thread.status && Thread.current[:name] == :overflow_items_controller }.each(&:kill)
      end

      execute_plugin 'on_initialize'

      yield self if block_given?
    end

    def self.crawl(*args, &block)
      new(*args, &block).takeover
    end

    def takeover
      @urls.each do |u|
        add_url(u) { |page| page.user_data.p_seeded = true }
      end
      return if internal_queue.empty?

      @on_crawl_start.each { |e| e.call(self) }

      execute_plugin 'on_crawl_start'
      @options[:workers].times do |worker_number|
        @workers_pool << Thread.new do
          @logger.debug { "Start worker #{worker_number}" }
          http  =  HTTP.new(@options)
          queue =  queue_factory
          queue.process(false, @options[:queue_timeout]) do |message|
            next if message.nil?

            execute_plugin 'on_message_received'

            page = Page.from_json message

            unless should_be_visited?(page.url, false)
              @logger.info { "[worker ##{worker_number}] Page (#{page.url}) is no more welcome." }
              queue.commit
              next
            end

            if page_exists? page
              @logger.info { "[worker ##{worker_number}] Page (#{page.url}) already stored." }
              queue.commit
              next
            end

            url = page.url.to_s
            @logger.debug { "[worker ##{worker_number}] Fetching page: [#{page.url}] Referer: #{page.referer} Depth: #{page.depth}" }

            execute_plugin 'on_before_download'

            pages = http.fetch_pages(url, page.referer, page.depth, page.user_data)
            if pages.count > 1
              rurls = pages.map { |e| e.url.to_s }.join(' --> ')
              @logger.info { "Got redirects! #{rurls}" }
              page = pages.pop
              page.aliases = pages.map(&:url)
              if page_exists? page
                @logger.info { "[worker ##{worker_number}] Page (#{page.url}) already stored." }
                queue.commit
                next
              end
            else
              page = pages.last
            end

            execute_plugin 'on_after_download'

            if page.error
              @logger.warn { "Page #{page.url} has error: #{page.error}" }
              incr_error
              @on_page_error.each { |e| e.call(page) }
            end

            # Execute on_before_save blocks
            @on_before_save.each { |e| e.call(page) }

            page.storable? && @storage.add(page)

            @logger.debug { "[worker ##{worker_number}] Fetched page: [#{page.url}] Referrer: [#{page.referer}] Depth: [#{page.depth}] Code: [#{page.code}] Response Time: [#{page.response_time}]" }
            @logger.info  { "[worker ##{worker_number}] Page (#{page.url}) downloaded" }

            incr_pages

            # Execute on_page_downloaded blocks
            @on_page_downloaded.each { |e| e.call(page) }

            if @options[:depth_limit] == false || @options[:depth_limit] > page.depth
              links_for(page).each do |url_to_visit|
                next unless should_be_visited?(url_to_visit)
                enqueue url_to_visit, page
              end
            else
              @logger.info { "[worker ##{worker_number}] Depth limit reached #{page.depth}" }
            end

            @logger.debug { "[worker ##{worker_number}] Queue size: #{queue.size}" }
            @overflow_manager.perform if @overflow_manager && queue.empty?
            execute_plugin 'on_message_processed'

            if SignalHandler.terminated?
              @logger.info { 'About to exit! Thanks for using Polipus' }
              queue.commit
              break
            end
            true
          end
        end
      end

      @workers_pool.each(&:join)
      @on_crawl_end.each { |e| e.call(self) }
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

    # A block of code will be executed on every page downloaded
    # The block takes the page as argument
    def on_page_downloaded(&block)
      @on_page_downloaded << block
      self
    end

    # A block of code will be executed when crawl session is over
    def on_crawl_end(&block)
      @on_crawl_end << block
      self
    end

    # A block of code will be executed when crawl session is starting
    def on_crawl_start(&block)
      @on_crawl_start << block
      self
    end

    # A block of code will be executed on every page downloaded
    # before being saved in the registered storage
    def on_before_save(&block)
      @on_before_save << block
      self
    end

    # A block of code will be executed whether a page contains an error
    def on_page_error(&block)
      @on_page_error << block
      self
    end

    # A block of code will be executed
    # on every page downloaded. The code is used to extract urls to visit
    # see links_for method
    def focus_crawl(&block)
      @focus_crawl_block = block
      self
    end

    def redis_options
      @options[:redis_options]
    end

    def queue_size
      internal_queue.size
    end

    def stats_reset!
      ["polipus:#{@job_name}:errors", "polipus:#{@job_name}:pages"].each { |e| redis.del e }
    end

    def redis_factory(&block)
      @redis_factory = block
      self
    end

    def url_tracker
      @url_tracker ||=
        @options[:url_tracker] ||=
          UrlTracker.bloomfilter(key_name: "polipus_bf_#{job_name}",
                                 redis: redis_factory_adapter,
                                 driver: 'lua')
    end

    def redis
      @redis ||= redis_factory_adapter
    end

    def add_to_queue(page)
      if [:url, :referer, :depth].all? { |method| page.respond_to?(method) }
        add_url(page.url, referer: page.referer, depth: page.depth)
      else
        add_url(page)
      end
    end

    # Enqueue an url, no matter what
    def add_url(url, params = {})
      page = Page.new(url, params)
      yield(page) if block_given?
      internal_queue << page.to_json
    end

    # Request to Polipus to stop its work (gracefully)
    # cler_queue = true if you want to delete all of the pending urls to visit
    def stop!(cler_queue = false)
      SignalHandler.terminate
      internal_queue.clear(true) if cler_queue
    end

    private

    # URLs enqueue policy
    def should_be_visited?(url, with_tracker = true)
      case
      # robots.txt
      when !allowed_by_robot?(url)
        false
      # Check against whitelist pattern matching
      when !@follow_links_like.empty? && @follow_links_like.none? { |p| url.path =~ p }
        false
      # Check against blacklist pattern matching
      when @skip_links_like.any? { |p| url.path =~ p }
        false
      # Page is marked as expired
      when page_expired?(Page.new(url))
        true
      # Check against url tracker
      when with_tracker && url_tracker.visited?(@options[:include_query_string_in_saved_page] ? url.to_s : url.to_s.gsub(/\?.*$/, ''))
        false
      else
        true
      end
    end

    # It extracts URLs from the page
    def links_for(page)
      page.domain_aliases = domain_aliases
      @focus_crawl_block.nil? ? page.links : @focus_crawl_block.call(page)
    end

    # whether a page is expired or not
    def page_expired?(page)
      return false if @options[:ttl_page].nil?
      stored_page = @storage.get(page)
      r = stored_page && stored_page.expired?(@options[:ttl_page])
      @logger.debug { "Page #{page.url} marked as expired" } if r
      r
    end

    # whether a page exists or not
    def page_exists?(page)
      return false if page.user_data && page.user_data.p_seeded
      @storage.exists?(page) && !page_expired?(page)
    end

    #
    # Returns +true+ if we are obeying robots.txt and the link
    # is granted access in it. Always returns +true+ when we are
    # not obeying robots.txt.
    #
    def allowed_by_robot?(link)
      return true if @robots.nil?
      @options[:obey_robots_txt] ? @robots.allowed?(link) : true
    end

    # The url is enqueued for a later visit
    def enqueue(url_to_visit, current_page)
      page_to_visit = Page.new(url_to_visit.to_s, referer: current_page.url.to_s, depth: current_page.depth + 1)
      internal_queue << page_to_visit.to_json
      to_track = @options[:include_query_string_in_saved_page] ? url_to_visit.to_s : url_to_visit.to_s.gsub(/\?.*$/, '')
      url_tracker.visit to_track
      @logger.debug { "Added (#{url_to_visit}) to the queue" }
    end

    # It creates a redis client
    def redis_factory_adapter
      if @redis_factory
        @redis_factory.call(redis_options)
      else
        Redis.new(redis_options)
      end
    end

    # It creates a new distributed queue
    def queue_factory
      Redis::Queue.new("polipus_queue_#{@job_name}", "bp_polipus_queue_#{@job_name}", redis: redis_factory_adapter)
    end

    # If stats enabled, it increments errors found
    def incr_error
      redis.incr "polipus:#{@job_name}:errors" if @options[:stats_enabled]
    end

    # If stats enabled, it increments pages downloaded
    def incr_pages
      redis.incr "polipus:#{@job_name}:pages" if @options[:stats_enabled]
    end

    # It handles the overflow item policy (if any)
    def overflow_items_controller
      @overflow_manager = QueueOverflow::Manager.new(self, queue_factory, @options[:queue_items_limit])

      # In the time, url policy may change so policy is re-evaluated
      @overflow_manager.url_filter do |page|
        should_be_visited?(page.url, false)
      end

      QueueOverflow::Worker.new(@overflow_manager)
    end

    def internal_queue
      @internal_queue ||= queue_factory
    end

    # It invokes a plugin method if any
    def execute_plugin(method)
      Polipus::Plugin.plugins.each do |k, p|
        next unless p.respond_to?(method)
        @logger.info { "Running plugin method #{method} on #{k}" }
        ret_val = p.send(method, self)
        instance_eval(&ret_val) if ret_val.is_a? Proc
      end
    end
  end
end
