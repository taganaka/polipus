module Polipus
  module QueueOverflow
    class Manager
      attr_accessor :url_filter
      def initialize(polipus, main_q, item_limit)
        @polipus = polipus
        @main_q  = main_q
        @adapter = @polipus.queue_overflow_adapter
        @item_limit = item_limit
        @redis = @polipus.redis
      end

      def url_filter(&block)
        @url_filter = block
      end

      def perform
        removed  = 0
        restored = 0

        if @main_q.size > @item_limit
          removed = rotate(@main_q, @adapter) { @main_q.size > @item_limit }
        elsif @main_q.size < @item_limit && !@adapter.empty?
          restored = rotate(@adapter, @main_q) { @main_q.size <= @item_limit }
        end
        [removed, restored]
      end

      private

      def rotate(source, dest)
        performed = 0
        loop do
          message = source.pop(true)
          if message
            page = Page.from_json message
            unless @polipus.storage.exists?(page)
              allowed = @url_filter.nil? ? true : @url_filter.call(page)
              if allowed
                dest << message
                performed += 1
              end
            end
          end
          source.commit if source.respond_to? :commit
          @redis.expire "polipus_queue_overflow-#{@polipus.job_name}.lock", 180
          break if !message || source.empty?
          break unless yield source, dest
        end
        performed
      end
    end
  end
end
