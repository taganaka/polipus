require "polipus/queue_overflow/mongo_queue"
module Polipus
  module QueueOverflow
    class MongoQueueCapped < MongoQueue
      def initialize(mongo_db, queue_name, options = {})
        super
        @max = @options[:max]
      end

      def push data
        super
        @semaphore.synchronize {
          s = size
          if s > @max
            docs = @mongo_db[@collection_name].find({},{:sort => {:_id => 1}, :fields => [:_id]}).limit(s-@max).map { |e| e['_id'] }
            @mongo_db[@collection_name].remove({:_id => {'$in' => docs}, '$isolated' => 1})
          end
        }
      end

      alias :size  :length
      alias :dec   :pop
      alias :shift :pop
      alias :enc   :push
      alias :<<    :push
    end
  end
end