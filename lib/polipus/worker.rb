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
                   :page_exists?,
                   :queue,
                   :should_be_visited?,
                   :storage

    def run
      queue.process(false, options[:queue_timeout]) do |message|
        next if message.nil?

        execute_plugin('on_message_received')
        process(Page.from_json(message))
        execute_plugin('on_message_processed')

        if SignalHandler.terminated?
          logger.info { 'About to exit! Thanks for using Polipus' }
          queue.commit
          break
        end
        true
      end
    end

    def process(page)
      unless should_be_visited?(page.url, false)
        logger.info { "[worker ##{worker_number}] Page (#{page.url}) is no more welcome." }
        return
      end

      if page_exists?(page)
        logger.info { "[worker ##{worker_number}] Page (#{page.url}) already stored." }
        return
      end

      url = page.url.to_s
      logger.debug { "[worker ##{worker_number}] Fetching page: [#{page.url}] Referer: #{page.referer} Depth: #{page.depth}" }

      execute_plugin 'on_before_download'

      pages = http.fetch_pages(url, page.referer, page.depth)
      if pages.count > 1
        rurls = pages.map { |e| e.url.to_s }.join(' --> ')
        logger.info { "Got redirects! #{rurls}" }
        page = pages.pop
        page.aliases = pages.map { |e| e.url }
        if page_exists?(page)
          logger.info { "[worker ##{worker_number}] Page (#{page.url}) already stored." }
          return
        end
      else
        page = pages.last
      end

      execute_plugin 'on_after_download'

      if page.error
        logger.warn { "Page #{page.url} has error: #{page.error}" }
        incr_error
        on_page_error_blocks.each { |e| e.call(page) }
      end

      # Execute on_before_save blocks
      on_before_save_blocks.each { |e| e.call(page) }

      page.storable? && storage.add(page)

      logger.debug { "[worker ##{worker_number}] Fetched page: [#{page.url}] Referrer: [#{page.referer}] Depth: [#{page.depth}] Code: [#{page.code}] Response Time: [#{page.response_time}]" }
      logger.info  { "[worker ##{worker_number}] Page (#{page.url}) downloaded" }

      incr_pages

      # Execute on_page_downloaded blocks
      on_page_downloaded_blocks.each { |e| e.call(page) }

      if options[:depth_limit] == false || options[:depth_limit] > page.depth
        links_for(page).each do |url_to_visit|
          next unless should_be_visited?(url_to_visit)
          enqueue url_to_visit, page, queue
        end
      else
        logger.info { "[worker ##{worker_number}] Depth limit reached #{page.depth}" }
      end

      logger.debug { "[worker ##{worker_number}] Queue size: #{queue.size}" }
      overflow_manager.perform if overflow_manager && queue.empty?
    end

    def http
      @http ||= HTTP.new(options)
    end
  end
end
