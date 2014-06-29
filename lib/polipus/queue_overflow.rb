# encoding: UTF-8
require 'polipus/queue_overflow/manager'
require 'polipus/queue_overflow/worker'
module Polipus
  module QueueOverflow
    def self.mongo_queue(mongo_db, queue_name, options = {})
      require 'polipus/queue_overflow/mongo_queue'
      mongo_db ||= Mongo::Connection.new('localhost', 27_017, pool_size: 15, pool_timeout: 5).db('polipus')
      fail 'First argument must be an instance of Mongo::DB' unless mongo_db.is_a?(Mongo::DB)
      self::MongoQueue.new mongo_db, queue_name, options
    end

    def self.mongo_queue_capped(mongo_db, queue_name, options = {})
      require 'polipus/queue_overflow/mongo_queue_capped'
      mongo_db ||= Mongo::Connection.new('localhost', 27_017, pool_size: 15, pool_timeout: 5).db('polipus')
      fail 'First argument must be an instance of Mongo::DB' unless mongo_db.is_a?(Mongo::DB)
      options[:max] = 1_000_000 if options[:max].nil?
      self::MongoQueueCapped.new mongo_db, queue_name, options
    end

    def self.dev_null_queue(_options = {})
      require 'polipus/queue_overflow/dev_null_queue'
      self::DevNullQueue.new
    end
  end
end
