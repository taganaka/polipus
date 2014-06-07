module Polipus
  module Storage
    class DevNull < Base
      def initialize(_options = {})
      end

      def add(_page)
      end

      def exists?(_page)
        false
      end

      def get(_page)
        nil
      end

      def remove(_page)
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
