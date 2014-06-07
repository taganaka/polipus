require 'redis-bloomfilter'
module Polipus
  module UrlTracker
    class Bloomfilter
      def initialize(options = {})
        @bf = Redis::Bloomfilter.new options
      end

      def visited?(url)
        @bf.include?(url)
      end

      def visit(url)
        @bf.insert url
      end

      def remove(url)
        @bf.remove url
      end

      def clear
        @bf.clear
      end
    end
  end
end
