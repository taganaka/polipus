module Polipus
  class Worker
    extend Forwardable

    attr_reader :crawler, :worker_number

    class << self
      def run(*args)
        new(*args).run
      end
    end

    def initialize(crawler, worker_number = nil)
      @crawler = crawler
      @worker_number = worker_number
    end

    def_delegators :crawler,
                   :enqueue,
                   :execute_plugin,
                   :incr_error,
                   :incr_pages,
                   :links_for,
                   :logger,
                   :on_before_save_blocks,
                   :on_page_downloaded_blocks,
                   :on_page_error_blocks,
                   :options,
                   :overflow_manager,
                   :queue,
                   :should_be_visited?,
                   :storage

    def run
      queue.process(false, options[:queue_timeout]) do |message|
        next if message.nil?

        execute_plugin('on_message_received')
        process(Page.from_json(message))
        execute_plugin('on_message_processed')

        manage_queue

        if SignalHandler.terminated?
          logger.info { 'About to exit! Thanks for using Polipus' }
          queue.commit
          break
        end
        true
      end
    end

    def process(page)
      return if shall_not_be_visited?(page)
      return if page_exists?(page)

      logger.debug { "[worker ##{worker_number}] Fetching page: [#{page.url}] Referer: #{page.referer} Depth: #{page.depth}" }

      execute_plugin('on_before_download')
      page = fetch(page)
      return unless page
      execute_plugin('on_after_download')

      check_for_error(page)
      store(page)

      logger.debug { "[worker ##{worker_number}] Fetched page: [#{page.url}] Referrer: [#{page.referer}] Depth: [#{page.depth}] Code: [#{page.code}] Response Time: [#{page.response_time}]" }
      logger.info  { "[worker ##{worker_number}] Page (#{page.url}) downloaded" }

      incr_pages

      on_downloaded(page)
      collect_links(page)
    end

    def http
      @http ||= HTTP.new(options)
    end

    def shall_not_be_visited?(page)
      if should_be_visited?(page.url, false)
        false
      else
        logger.info { "[worker ##{worker_number}] Page (#{page.url}) is no more welcome." }
        true
      end
    end

    def page_exists?(page)
      if crawler.page_exists?(page)
        logger.info { "[worker ##{worker_number}] Page (#{page.url}) already stored." }
        true
      else
        false
      end
    end

    def fetch(page)
      pages = http.fetch_pages(page.url, page.referer, page.depth)
      if pages.count > 1
        rurls = pages.map { |e| e.url.to_s }.join(' --> ')
        logger.info { "Got redirects! #{rurls}" }
        page = pages.pop
        page.aliases = pages.map { |e| e.url }

        page_exists?(page) ? nil : page
      else
        pages.last
      end
    end

    def check_for_error(page)
      if page.error
        logger.warn { "Page #{page.url} has error: #{page.error}" }
        incr_error
        on_page_error_blocks.each { |e| e.call(page) }
      end
    end

    def store(page)
      # Execute on_before_save blocks
      on_before_save_blocks.each { |e| e.call(page) }

      page.storable? && storage.add(page)
    end

    # Execute on_page_downloaded blocks
    def on_downloaded(page)
      on_page_downloaded_blocks.each { |e| e.call(page) }
    end

    def collect_links(page)
      if options[:depth_limit] == false || options[:depth_limit] > page.depth
        links_for(page).each do |url_to_visit|
          next unless should_be_visited?(url_to_visit)
          enqueue url_to_visit, page, queue
        end
      else
        logger.info { "[worker ##{worker_number}] Depth limit reached #{page.depth}" }
      end
    end

    def manage_queue
      logger.debug { "[worker ##{worker_number}] Queue size: #{queue.size}" }
      overflow_manager.perform if overflow_manager && queue.empty?
    end
  end
end
