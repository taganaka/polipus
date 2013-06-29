module Polipus
  module QueueOverflow
    class Manager
      def initialize(polipus, main_q, item_limit)
        @polipus = polipus
        @main_q  = main_q
        @adapter = @polipus.queue_overflow_adapter
        @item_limit = item_limit
      end

      def perform
        removed = 0
        restored = 0

        if @main_q.size > @item_limit
          removed = rotate @main_q, @adapter,(@main_q.size - @item_limit)
        elsif @main_q.size < @item_limit && !@adapter.empty?
          restored = rotate @adapter, @main_q,(@item_limit -  @main_q.size)
        end
        [removed, restored]
      end

      private
        def rotate source, dest, items
          performed = 0
          1.upto(items){|i|
            message = source.pop(true)
            if message
              dest << message
              performed += 1
            end
            break if !message || source.empty?
          }
          performed
        end
    end
  end
end