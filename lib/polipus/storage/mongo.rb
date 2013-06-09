require "mongo"
module Polipus
  module Storage
    class Mongo < Base
      BINARY_FIELDS = %w(body headers data)
      def initialize(options = {})
        @mongo      = options[:mongo]
        @collection = options[:collection]
        @mongo[@collection].ensure_index(:uuid, :unique => true, :drop_dups => true, :background => true)
      end

      def add page
        obj = page.to_hash
        obj['uuid'] = uuid(page)
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

      def all
        @mongo[@collection].find({})
      end

      def clear
        @mongo[@collection].drop
      end

      private
        def load_page(hash)
          BINARY_FIELDS.each do |field|
            hash[field] = hash[field].to_s
          end
          Page.from_hash(hash)
        end

    end
  end
end