require 'thread'
require 'mongo'
module Polipus
  module QueueOverflow
    class MongoQueue
      def initialize(mongo_db, queue_name, options = {})
        @mongo_db = mongo_db
        @collection_name = "polipus_q_overflow_#{queue_name}"
        @semaphore = Mutex.new
        @options = options
        @options[:ensure_uniq] ||= false
        @options[:ensure_uniq] && ensure_index
      end

      def length
        @mongo_db[@collection_name].count
      end

      def empty?
        !(length > 0)
      end

      def clear
        @mongo_db[@collection_name].drop
        @options[:ensure_uniq] && ensure_index
      end

      def push(data)
        if @options[:ensure_uniq]
          @mongo_db[@collection_name].update({ payload: data }, { payload: data }, { upsert: 1, w: 1 })
        else
          @mongo_db[@collection_name].insert(payload: data)
        end
        true
      end

      def pop(_ = false)
        @semaphore.synchronize do
          doc = @mongo_db[@collection_name].find({}, sort: { _id: 1 }).limit(1).first
          return nil if doc.nil?
          @mongo_db[@collection_name].remove(_id: doc['_id'])
          doc && doc['payload'] ? doc['payload'] : nil
        end
      end

      alias_method :size,  :length
      alias_method :dec,   :pop
      alias_method :shift, :pop
      alias_method :enc,   :push
      alias_method :<<,    :push

      protected

      def ensure_index
        @mongo_db[@collection_name].ensure_index({ payload: 1 }, { background: 1, unique: 1, drop_dups: 1 })
      end
    end
  end
end
