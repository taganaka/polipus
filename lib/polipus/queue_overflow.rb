require "polipus/queue_overflow/manager"
module Polipus
  module QueueOverflow
    def self.mongo_queue(mongo_db, queue_name, options = {})
      require "polipus/queue_overflow/mongo_queue"
      mongo_db ||= Mongo::Connection.new("localhost", 27017, :pool_size => 15, :pool_timeout => 5).db('polipus')
      raise "First argument must be an instance of Mongo::DB" unless mongo_db.is_a?(Mongo::DB)
      self::MongoQueue.new mongo_db, queue_name, options
    end
  end
end