# encoding: UTF-8
require 'open-uri'
require 'uri'
require 'timeout'
module Polipus
  # Original code taken from
  # https://github.com/chriskite/robotex/blob/master/lib/robotex.rb

  class Robotex
    DEFAULT_TIMEOUT = 3
    VERSION = '1.0.0'

    attr_reader :user_agent

    class ParsedRobots
      def initialize(uri, user_agent)
        io = Robotex.get_robots_txt(uri, user_agent)
        if !io || io.content_type != 'text/plain' || io.status != %w(200 OK)
          io = StringIO.new("User-agent: *\nAllow: /\n")
        end

        @disallows = {}
        @allows = {}
        @delays = {}
        agent = /.*/
        io.each do |line|
          next if line =~ /^\s*(#.*|$)/
          arr = line.split(':')
          key = arr.shift
          value = arr.join(':').strip
          value.strip!
          case key.downcase
          when 'user-agent'
            agent = to_regex(value)
          when 'allow'
            unless value.empty?
              @allows[agent] ||= []
              @allows[agent] << to_regex(value)
            end
          when 'disallow'
            unless value.empty?
              @disallows[agent] ||= []
              @disallows[agent] << to_regex(value)
            end
          when 'crawl-delay'
            @delays[agent] = value.to_i
          end
        end
        @parsed = true
      end

      def allowed?(uri, user_agent)
        return true unless @parsed
        allowed = true
        uri = URI.parse(uri.to_s) unless uri.is_a?(URI)
        path = uri.request_uri

        @allows.each do |key, value|
          unless allowed
            if user_agent =~ key
              value.each do |rule|
                path =~ rule && allowed = true
              end
            end
          end
        end

        @disallows.each do |key, value|
          if user_agent =~ key
            value.each do |rule|
              path =~ rule && allowed = false
            end
          end
        end

        allowed
      end

      def delay(user_agent)
        @delays.each do |agent, delay|
          return delay if agent =~ user_agent
        end
        nil
      end

      protected

      def to_regex(pattern)
        pattern = Regexp.escape(pattern)
        pattern.gsub!(Regexp.escape('*'), '.*')
        Regexp.compile("^#{pattern}")
      end
    end

    def self.get_robots_txt(uri, user_agent)
      Timeout.timeout(Robotex.timeout) do
        URI.join(uri.to_s, '/robots.txt').open('User-Agent' => user_agent) rescue nil
      end
    rescue Timeout::Error
      STDERR.puts 'robots.txt request timed out'
    end

    class << self
      attr_writer :timeout
    end

    def self.timeout
      @timeout || DEFAULT_TIMEOUT
    end

    def initialize(user_agent = nil)
      user_agent = "Robotex/#{VERSION} (http://www.github.com/chriskite/robotex)" if user_agent.nil?
      @user_agent = user_agent
      @last_accessed = Time.at(1)
      @parsed = {}
    end

    def parse_host(uri)
      uri = URI.parse(uri.to_s) unless uri.is_a?(URI)
      @parsed[uri.host] ||= ParsedRobots.new(uri, @user_agent)
    end

    #
    # Download the server's robots.txt, and return try if we are allowed to acces the url, false otherwise
    #
    def allowed?(uri)
      parse_host(uri).allowed?(uri, @user_agent)
    end

    #
    # Return the value of the Crawl-Delay directive, or nil if none
    def delay(uri)
      parse_host(uri).delay(@user_agent)
    end

    #
    # Sleep for the amount of time necessary to obey the Crawl-Delay specified by the server
    #
    def delay!(uri)
      delay = delay(uri)
      sleep delay - (Time.now - @last_accessed) if delay
      @last_accessed = Time.now
    end
  end
end
