require "mongo"
require "zlib"
module Polipus
  module Storage
    class MongoStore < Base
      BINARY_FIELDS = %w(body headers data)
      def initialize(options = {})
        @mongo      = options[:mongo]
        @collection = options[:collection]
        @mongo[@collection].ensure_index(:uuid, :unique => true, :drop_dups => true, :background => true)
      end

      def add page
        obj = page.to_hash
        obj['uuid'] = uuid(page)
        obj['body'] = hash_page['body'] = Zlib::Inflate.inflate(page['body'].to_s) if page['body']
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
          hash['body'] = Zlib::Deflate.deflate(hash['body']) if hash['body']
          Page.from_hash(hash)
        end

    end
  end
end