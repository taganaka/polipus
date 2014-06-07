module Polipus
  module UrlTracker
    def self.bloomfilter(options = {})
      require 'polipus/url_tracker/bloomfilter'
      options[:size]       ||= 1_000_000
      options[:error_rate] ||= 0.01
      options[:key_name]   ||= 'polipus-bloomfilter'
      options[:redis]      ||= Redis.current
      options[:driver]     ||= 'lua'
      self::Bloomfilter.new options
    end

    def self.redis_set(options = {})
      require 'polipus/url_tracker/redis_set'
      options[:redis]      ||= Redis.current
      options[:key_name]   ||= 'polipus-set'
      self::RedisSet.new options
    end
  end
end
