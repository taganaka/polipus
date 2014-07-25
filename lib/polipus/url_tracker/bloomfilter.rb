# encoding: UTF-8
require 'redis-bloomfilter'
module Polipus
  module UrlTracker
    class Bloomfilter
      def initialize(options = {})
        @mutex = Mutex.new
        @bf = Redis::Bloomfilter.new options
      end

      def visited?(url)
        @mutex.synchronize do
          r = false
          loop do 
            @bf.options[:redis].watch("#{@bf.options[:key_name]}:count")
            @bf.options[:redis].multi
            r = @bf.include?(url)
            break if @bf.options[:redis].exec
          end
          r
        end
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
