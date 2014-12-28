# encoding: UTF-8
require 'rethinkdb'
require 'zlib'
require 'thread'

module Polipus
  module Storage
    class RethinkStore < Base
      BINARY_FIELDS = %w(body headers data)
      def initialize(options = {})
        @r       = RethinkDB::RQL.new
        @rethink = options[:conn]
        @table   = options[:table]
        @r.table_create(@table).run(@rethink) unless @r.table_list.run(@rethink).include?(@table)

        begin
          @r.get(@table).ensure_index(:uuid, unique: true, dropDups: true, background: true)
        rescue Exception
        end

        @compress_body = options[:compress_body] ||= true
        @except = options[:except] ||= []
        @semaphore = Mutex.new
      end

      def add(page)
        @semaphore.synchronize do
          obj = page.to_hash
          @except.each { |e| obj.delete e.to_s }
          obj[:id] = uuid(page)
          obj['body'] = Zlib::Deflate.deflate(obj['body']) if @compress_body && obj['body']
          obj['created_at'] ||= Time.now.to_i
          BINARY_FIELDS.each do |field|
            # Use some marshalling?
            obj[field] = @r.binary(obj[field]) unless obj[field].nil?
          end
          # @r.table(@table).get(id).update(obj).run(@rethink)
          @r.table(@table).insert(obj).run(@rethink)
          obj[:id]
        end
      end

      def exists?(page)
        @semaphore.synchronize do
          doc = @r.table(@table).get(uuid(page)).run(@rethink)
          !doc.nil?
        end
      end

      def get(page)
        @semaphore.synchronize do
          data = @r.table(@table).get(uuid(page)).run(@rethink)
          return load_page(data) if data
        end
      end

      def remove(page)
        @semaphore.synchronize do
          @r.table(@table).get(uuid(page)).delete.run(@rethink)
        end
      end

      def count
        @r.table(@table).count.run(@rethink)
      end

      def each
        @r.table(@table).run(@rethink).each do |doc|
          page = load_page(doc)
          yield doc[:id], page
        end
      end

      def clear
        @r.table(@table).delete.run(@rethink)
      end

      private


      def load_page(hash)
        BINARY_FIELDS.each do |field|
          hash[field] = hash[field].to_s
        end
        hash['body'] = Zlib::Inflate.inflate(hash['body']) if @compress_body && hash['body'] && !hash['body'].empty?
        page = Page.from_hash(hash)
        if page.fetched_at.nil?
          page.fetched_at = hash['created_at']
        end
        page
      end
    end
  end
end
