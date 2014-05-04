require "mongo"
require "zlib"
require "thread"
module Polipus
  module Storage
    class MongoStore < Base
      BINARY_FIELDS = %w(body headers data)
      def initialize(options = {})
        @mongo      = options[:mongo]
        @collection = options[:collection]
        @mongo.create_collection(@collection)
        @mongo[@collection].ensure_index(:uuid, :unique => true, :drop_dups => true, :background => true)
        @compress_body = options[:compress_body] ||= true
        @except = options[:except] ||= []
        @semaphore = Mutex.new
      end

      def add page
        @semaphore.synchronize {
          obj = page.to_hash
          @except.each {|e| obj.delete e.to_s}
          obj['uuid'] = uuid(page)
          obj['body'] = Zlib::Deflate.deflate(obj['body']) if @compress_body && obj['body']
          BINARY_FIELDS.each do |field|
            obj[field] = BSON::Binary.new(obj[field]) unless obj[field].nil?
          end
          @mongo[@collection].update({:uuid => obj['uuid']}, obj, {:upsert => true, :w => 1})
          obj['uuid']
        }
      end

      def exists?(page)
        @semaphore.synchronize {
          doc = @mongo[@collection].find({:uuid => uuid(page)}, {:fields => [:_id]}).limit(1).first
          !doc.nil?
        }
      end

      def get page
        @semaphore.synchronize {
          data = @mongo[@collection].find({:uuid => uuid(page)}).limit(1).first
          return load_page(data) if data
        }
      end

      def remove page
        @semaphore.synchronize {
          @mongo[@collection].remove({:uuid => uuid(page)})
        }
      end

      def count
        @mongo[@collection].count
      end

      def each
        @mongo[@collection].find({},:timeout => false) do |cursor|
          cursor.each do |doc|
            page = load_page(doc)
            yield doc['uuid'], page 
          end
        end
      end

      def clear
        @mongo[@collection].drop
      end

      private
        def load_page(hash)
          BINARY_FIELDS.each do |field|
            hash[field] = hash[field].to_s
          end
          begin
            hash['body'] = Zlib::Inflate.inflate(hash['body']) if @compress_body && hash['body'] && !hash['body'].empty?
            return Page.from_hash(hash)
          rescue
          end
          nil
        end

    end
  end
end