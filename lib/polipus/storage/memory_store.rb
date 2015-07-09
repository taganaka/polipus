# encoding: UTF-8
require 'thread'
module Polipus
  module Storage
    class MemoryStore < Base
      def initialize(_options = {})
        @store = {}
        @semaphore = Mutex.new
      end

      def add(page)
        @semaphore.synchronize do
          u = uuid(page)
          @store[u] = page
          u
        end
      end

      def exists?(page)
        @semaphore.synchronize do
          @store.key?(uuid(page))
        end
      end

      def get(page)
        @semaphore.synchronize do
          @store[uuid(page)]
        end
      end

      def remove(page)
        @semaphore.synchronize do
          @store.delete(uuid(page))
        end
      end

      def count
        @semaphore.synchronize do
          @store.count
        end
      end

      def each
        @store.each do |k, v|
          yield k, v
        end
      end

      def clear
        @semaphore.synchronize do
          @store = {}
        end
      end
    end
  end
end
