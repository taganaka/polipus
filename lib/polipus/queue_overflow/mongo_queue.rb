# encoding: UTF-8
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
        @mongo_db[@collection_name].find.count
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
          @mongo_db[@collection_name].find(payload: data).replace_one({ payload: data }, upsert: true)
        else
          @mongo_db[@collection_name].insert_one(payload: data)
        end
        true
      end

      def pop(_ = false)
        @semaphore.synchronize do
          doc = @mongo_db[@collection_name].find.sort(_id: 1).limit(1).first
          return nil if doc.nil?
          @mongo_db[@collection_name].find(_id: doc['_id']).delete_one
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
        # @TODO: Drop dups option was removed. We may want to add something here to remove duplications
        @mongo_db[@collection_name].indexes.create_one({ payload: 1 }, background: true, unique: true)
      end
    end
  end
end
