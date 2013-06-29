require "mongo"
require "zlib"
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
      end

      def add page
        obj = page.to_hash
        obj['uuid'] = uuid(page)
        obj['body'] = Zlib::Deflate.deflate(obj['body']) if @compress_body && obj['body']
        BINARY_FIELDS.each do |field|
          obj[field] = BSON::Binary.new(obj[field]) unless obj[field].nil?
        end
        @mongo[@collection].update({:uuid => uuid(page)}, obj, :upsert => true)
      end

      def exists?(page)
        @mongo[@collection].count({:uuid => uuid(page)}) > 0
      end

      def get page
        data = @mongo[@collection].find({:uuid => uuid(page)}).limit(1).first
        if data
          load_page(data)
        end
      end

      def remove page
        @mongo[@collection].remove({:uuid => uuid(page)})
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