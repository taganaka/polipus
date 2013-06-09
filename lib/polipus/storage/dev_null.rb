module Polipus
  module Storage
    class DevNull < Base

      def initialize(options = {})
      end

      def add page
      end

      def exists?(page)
        false
      end

      def get page
        nil
      end

      def remove page
        false
      end

      def count
        0
      end

      def each
        yield nil
      end

      def clear
      end
    end
  end
end