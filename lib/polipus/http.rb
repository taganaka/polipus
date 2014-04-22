require "net/https"
require "polipus/page"
require "zlib"
require 'http/cookie'

module Polipus
  class HTTP
    # Maximum number of redirects to follow on each get_response
    REDIRECT_LIMIT = 5

    def initialize(opts = {})
      @connections = {}
      @connections_hits = {}
      @opts = opts
    end

    #
    # Fetch a single Page from the response of an HTTP request to *url*.
    # Just gets the final destination page.
    #
    def fetch_page(url, referer = nil, depth = nil)
      fetch_pages(url, referer, depth).last
    end

    #
    # Create new Pages from the response of an HTTP request to *url*,
    # including redirects
    #
    def fetch_pages(url, referer = nil, depth = nil)
      begin
        url = URI(url) unless url.is_a?(URI)
        pages = []
        get(url, referer) do |response, code, location, redirect_to, response_time|
          body = response.body.dup
          if response.to_hash.fetch('content-encoding', [])[0] == 'gzip'
            gzip = Zlib::GzipReader.new(StringIO.new(body))    
            body = gzip.read
          end
          pages << Page.new(location, :body => response.body.dup,
                                      :code => code,
                                      :headers => response.to_hash,
                                      :referer => referer,
                                      :depth => depth,
                                      :redirect_to => redirect_to,
                                      :response_time => response_time)
        end

        return pages
      rescue StandardError => e
        if verbose?
          puts e.inspect
          puts e.backtrace
        end
        return [Page.new(url, :error => e)]
      end
    end

    #
    # The maximum number of redirects to follow
    #
    def redirect_limit
      @opts[:redirect_limit] || REDIRECT_LIMIT
    end

    #
    # The user-agent string which will be sent with each request,
    # or nil if no such option is set
    #
    def user_agent
      @opts[:user_agent]
    end

   
    #
    # The proxy address string
    #
    def proxy_host
      return proxy_host_port.first unless @opts[:proxy_host_port].nil?
      @opts[:proxy_host].respond_to?(:call) ? @opts[:proxy_host].call(self) : @opts[:proxy_host]
    end

    #
    # The proxy port
    #
    def proxy_port
      return proxy_host_port.last unless @opts[:proxy_host_port].nil?
      @opts[:proxy_port].respond_to?(:call) ? @opts[:proxy_port].call(self) : @opts[:proxy_port]
    end

    #
    # Shorthand to get proxy info with a single call
    # It returns an array of ['addr', port]
    #
    def proxy_host_port
      @opts[:proxy_host_port].respond_to?(:call) ? @opts[:proxy_host_port].call(self) : @opts[:proxy_host_port]
    end

    #
    # HTTP read timeout in seconds
    #
    def read_timeout
      @opts[:read_timeout]
    end

    #
    # HTTP open timeout in seconds
    #
    def open_timeout
      @opts[:open_timeout]
    end

    # Does this HTTP client accept cookies from the server?
    #
    def accept_cookies?
      @opts[:accept_cookies]
    end

    def cookie_jar
      @opts[:cookie_jar] ||= ::HTTP::CookieJar.new
      @opts[:cookie_jar]
    end

    private

    #
    # Retrieve HTTP responses for *url*, including redirects.
    # Yields the response object, response code, and URI location
    # for each response.
    #
    def get(url, referer = nil)
      limit = redirect_limit
      loc = url
      begin
          # if redirected to a relative url, merge it with the host of the original
          # request url
          loc = url.merge(loc) if loc.relative?

          response, response_time = get_response(loc, referer)
          code = Integer(response.code)
          redirect_to = response.is_a?(Net::HTTPRedirection) ? URI(response['location']).normalize : nil
          yield response, code, loc, redirect_to, response_time
          limit -= 1
      end while (loc = redirect_to) && allowed?(redirect_to, url) && limit > 0
    end

    #
    # Get an HTTPResponse for *url*, sending the appropriate User-Agent string
    #
    def get_response(url, referer = nil)
      full_path = url.query.nil? ? url.path : "#{url.path}?#{url.query}"

      opts = {}
      opts['User-Agent'] = user_agent if user_agent
      opts['Referer'] = referer.to_s if referer
      opts['Cookie']  = ::HTTP::Cookie.cookie_value(cookie_jar.cookies(url)) if accept_cookies?

      retries = 0
      begin
        start = Time.now()
        # format request
        req = Net::HTTP::Get.new(full_path, opts)
        # HTTP Basic authentication
        req.basic_auth url.user, url.password if url.user
        response = connection(url).request(req)
        finish = Time.now()
        response_time = ((finish - start) * 1000).round
        cookie_jar.parse(response["Set-Cookie"], url) if accept_cookies?
        return response, response_time
      rescue Timeout::Error, Net::HTTPBadResponse, EOFError => e
        
        puts e.inspect if verbose?
        refresh_connection(url)
        retries += 1
        retry unless retries > 3
      end
    end

    def connection(url)
      @connections[url.host] ||= {}
      @connections_hits[url.host] ||= {}

      if conn = @connections[url.host][url.port]
        if @opts[:connection_max_hits] && @connections_hits[url.host][url.port] >= @opts[:connection_max_hits]
          @opts[:logger].debug {"Connection #{url.host}:#{url.port} is staled, refreshing"} if @opts[:logger]
          return refresh_connection url
        end
        @connections_hits[url.host][url.port] += 1
        return conn
      end

      refresh_connection url
    end

    def refresh_connection(url)
      proxy_host, proxy_port = proxy_host_port unless @opts[:proxy_host_port].nil?

      if @opts[:logger] && proxy_host && proxy_port
        @opts[:logger].debug {"Request #{url} using proxy: #{proxy_host}:#{proxy_port}"}
      end

      http = Net::HTTP.new(url.host, url.port, proxy_host, proxy_port)

      http.read_timeout = read_timeout if !!read_timeout
      http.open_timeout = open_timeout if !!open_timeout

      if url.scheme == 'https'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      @connections_hits[url.host][url.port] = 1
      @connections[url.host][url.port] = http.start 
    end

    def verbose?
      @opts[:verbose]
    end

    #
    # Allowed to connect to the requested url?
    #
    def allowed?(to_url, from_url)
      to_url.host.nil? || (to_url.host == from_url.host)
    end

  end
end
