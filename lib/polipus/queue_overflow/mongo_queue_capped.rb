# encoding: UTF-8
require 'polipus/queue_overflow/mongo_queue'
module Polipus
  module QueueOverflow
    class MongoQueueCapped < MongoQueue
      def initialize(mongo_db, queue_name, options = {})
        super
        @max = @options[:max]
      end

      def push(data)
        super
        @semaphore.synchronize do
          s = size
          if s > @max
            docs = @mongo_db[@collection_name].find.sort(_id: 1).projection(_id: 1).limit(s - @max).map { |e| e['_id'] }
            @mongo_db[@collection_name].find(_id: { '$in' => docs }).delete_many
          end
        end
      end

      alias_method :size,  :length
      alias_method :dec,   :pop
      alias_method :shift, :pop
      alias_method :enc,   :push
      alias_method :<<,    :push
    end
  end
end
