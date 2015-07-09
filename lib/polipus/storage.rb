require 'polipus/storage/base'

module Polipus
  module Storage
    COLLECTION = 'pages'

    def self.mongo_store(mongo = nil, collection = COLLECTION, except = [])
      require 'polipus/storage/mongo_store'
      mongo ||= Mongo::Client.new(['localhost:27_017'], database: 'polipus')
      fail 'First argument must be an instance of Mongo::Client' unless mongo.is_a?(Mongo::Client)
      self::MongoStore.new(mongo: mongo, collection: collection, except: except)
    end

    def self.rethink_store(conn = nil, table = COLLECTION, except = [])
      require 'polipus/storage/rethink_store'
      conn ||= RethinkDB::RQL.new.connect(host: 'localhost', port: 28_015, db: 'polipus')
      fail "First argument must be a RethinkDB::Connection, got `#{conn.class}`" unless conn.is_a?(RethinkDB::Connection)
      self::RethinkStore.new(conn: conn, table: table,  except: except)
    end

    def self.dev_null
      require 'polipus/storage/dev_null'
      self::DevNull.new
    end

    def self.memory_store
      require 'polipus/storage/memory_store'
      self::MemoryStore.new
    end
  end
end
