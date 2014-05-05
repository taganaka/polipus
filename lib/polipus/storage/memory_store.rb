require "thread"
module Polipus
  module Storage
    class MemoryStore < Base

      def initialize(options = {})
        @store = Hash.new
        @semaphore = Mutex.new
      end

      def add page
        @semaphore.synchronize {
          u = uuid(page)
          @store[u] = page
          u
        }
      end

      def exists?(page)
        @semaphore.synchronize {
          @store.key?(uuid(page))
        }
      end

      def get page
        @semaphore.synchronize {
          @store[uuid(page)]
        }
      end

      def remove page
        @semaphore.synchronize {
          @store.delete(uuid(page))
        }
      end

      def count
        @semaphore.synchronize {
          @store.count
        }
      end

      def each
        @semaphore.synchronize {
          @store.each do |k,v|
            yield k,v
          end
        }
      end

      def clear
        @semaphore.synchronize {
          @store = Hash.new
        }
      end
    end
  end
end