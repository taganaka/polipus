require 'polipus/storage/base'
module Polipus
  module Storage
    def self.mongo_store(mongo = nil, collection_name = 'pages', except = [])
      require 'polipus/storage/mongo_store'
      mongo ||= Mongo::Connection.new('localhost', 27_017, pool_size: 15, pool_timeout: 5).db('polipus')
      fail 'First argument must be an instance of Mongo::DB' unless mongo.is_a?(Mongo::DB)
      self::MongoStore.new(mongo: mongo, collection: collection_name, except: except)
    end

    def self.s3_store(bucket_name = 'pages', aws_credential = {}, except = [])
      require 'polipus/storage/s3_store'

      if aws_credential[:access_key_id].nil? || aws_credential[:secret_access_key].nil?
        fail 'You have to specify AWS crediantials: :access_key_id and :secret_access_key'
      end

      self::S3Store.new(
        bucket: bucket_name,
        access_key_id: aws_credential[:access_key_id],
        secret_access_key: aws_credential[:secret_access_key],
        except: except
      )
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
