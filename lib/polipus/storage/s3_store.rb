require 'aws/s3'
require 'zlib'
require 'thread'
require 'json'
module Polipus
  module Storage
    class S3Store < Base
      def initialize(options = {})
        @options = options
        @except = @options[:except] ||= []
        @semaphore = Mutex.new

        AWS::S3::Base.establish_connection!(
          access_key_id: @options[:access_key_id],
          secret_access_key: @options[:secret_access_key]
        )
        @options[:bucket] = "com.polipus.pages.#{@options[:bucket]}"
        begin
          @bucket = AWS::S3::Bucket.find(@options[:bucket])
        rescue AWS::S3::NoSuchBucket
          create_bucket
        end
      end

      def add(page)
        @semaphore.synchronize do
          obj = page.to_hash
          @except.each { |e| obj.delete e.to_s }
          puuid = uuid(page)
          obj['uuid'] = puuid
          data = Zlib::Deflate.deflate(obj.to_json)
          AWS::S3::S3Object.store(puuid, data, @bucket.name)
          puuid
        end
      end

      def exists?(page)
        AWS::S3::S3Object.exists? uuid(page), @bucket.name
      end

      def get(page)
        @semaphore.synchronize do
          if exists?(page)
            data = AWS::S3::S3Object.find(uuid(page), @bucket.name).value
            return load_page(data)
          end
          nil
        end
      end

      def remove(page)
        @semaphore.synchronize do
          exists?(page) && AWS::S3::S3Object.delete(uuid(page), @bucket.name)
          true
        end
      end

      def count
        @bucket.size
      end

      def clear
        AWS::S3::Bucket.delete(@bucket.name, force: true)
        create_bucket
      end

      def each
        objects = []
        last_key = nil
        loop do
          objects = AWS::S3::Bucket.objects(@bucket.name, marker: last_key)
          break if objects.size == 0
          objects.each do |o|
            page = load_page(o.value)
            yield o.key, page
          end
          last_key   = objects.last.key
        end
      end

      private

      def load_page(data)
        payload = Zlib::Inflate.inflate(data)
        hash = JSON.parse(payload)
        Page.from_hash(hash)
      end

      def create_bucket
        AWS::S3::Bucket.create(@options[:bucket])
        @bucket = AWS::S3::Bucket.find(@options[:bucket])
      end
    end
  end
end
