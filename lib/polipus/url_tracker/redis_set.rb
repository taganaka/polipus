module Polipus
  module UrlTracker
    class RedisSet
      
      def initialize(options = {})
        @redis    = options[:redis] || Redis.current
        @set_name = options[:key_name]
      end

      def visited?(url)
        @redis.sismember(@set_name,url)
      end

      def visit url
        @redis.sadd(@set_name, url)
      end

      def clear
        @redis.del @set_name
      end
    end
  end
end