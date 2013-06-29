require "thread"
module Polipus
  module QueueOverflow
    class MongoQueue
      def initialize(mongo_db, queue_name)
        @mongo_db = mongo_db
        @collection_name = "polipus_q_overflow_#{queue_name}"
        @semaphore = Mutex.new
      end

      def length
        @mongo_db[@collection_name].count
      end

      def empty?
        !(length > 0)
      end

      def clear
        @mongo_db[@collection_name].drop
      end

      def push data
        @mongo_db[@collection_name].insert({:payload => data})
      end

      def pop
        @semaphore.synchronize {
          doc = @mongo_db[@collection_name].find({},:sort => {:_id => 1}).limit(1).first
          return nil if doc.nil?
          @mongo_db[@collection_name].remove(:_id => doc['_id'])
          return doc && doc['payload'] ? doc['payload'] : nil
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