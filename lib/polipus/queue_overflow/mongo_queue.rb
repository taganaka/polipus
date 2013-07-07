require "thread"
module Polipus
  module QueueOverflow
    class MongoQueue
      def initialize(mongo_db, queue_name, options = {})
        @mongo_db = mongo_db
        @collection_name = "polipus_q_overflow_#{queue_name}"
        @semaphore = Mutex.new
        @options = options
        @options[:ensure_uniq] ||= false
        if @options[:ensure_uniq]
          ensure_index
        end
      end

      def length
        @mongo_db[@collection_name].count
      end

      def empty?
        !(length > 0)
      end

      def clear
        @mongo_db[@collection_name].drop
        if @options[:ensure_uniq]
          ensure_index
        end
      end

      def push data
        unless @options[:ensure_uniq]
          @mongo_db[@collection_name].insert({:payload => data})  
        else
          @mongo_db[@collection_name].update({:payload => data}, {:payload => data}, {:upsert => 1, :w => 1})
        end
        true        
      end

      def pop(_ = false)
        @semaphore.synchronize {
          doc = @mongo_db[@collection_name].find({},:sort => {:_id => 1}).limit(1).first
          return nil if doc.nil?
          @mongo_db[@collection_name].remove(:_id => doc['_id'])
          doc && doc['payload'] ? doc['payload'] : nil
        }
      end
      
      alias :size  :length
      alias :dec   :pop
      alias :shift :pop
      alias :enc   :push
      alias :<<    :push

      protected
        def ensure_index
          @mongo_db[@collection_name].ensure_index({:payload => 1},{:background => 1, :unique => 1, :drop_dups => 1})
        end
    end
  end
end