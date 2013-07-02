require "polipus/storage/base"
module Polipus
  module Storage
    def self.mongo_store(mongo = nil, collection_name = 'pages', except = [])
      require 'polipus/storage/mongo_store'
      mongo ||= Mongo::Connection.new("localhost", 27017, :pool_size => 15, :pool_timeout => 5).db('polipus')
      raise "First argument must be an instance of Mongo::DB" unless mongo.is_a?(Mongo::DB)
      self::MongoStore.new(:mongo => mongo, :collection => collection_name, :except => except)
    end

    def self.dev_null
      require 'polipus/storage/dev_null'
      self::DevNull.new
    end
  end
end