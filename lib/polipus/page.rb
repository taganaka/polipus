require 'nokogiri'
require 'json'
require 'ostruct'
require 'set'
module Polipus
  class Page

    # The URL of the page
    attr_reader :url
    # The raw HTTP response body of the page
    attr_reader :body
    # Headers of the HTTP response
    attr_reader :headers
    # URL of the page this one redirected to, if any
    attr_reader :redirect_to
    # Exception object, if one was raised during HTTP#fetch_page
    attr_reader :error
    # Integer response code of the page
    attr_accessor :code
    # Depth of this page from the root of the crawl. This is not necessarily the
    # shortest path; use PageStore#shortest_paths! to find that value.
    attr_accessor :depth
    # URL of the page that brought us to this page
    attr_accessor :referer
    # Response time of the request for this page in milliseconds
    attr_accessor :response_time
    # OpenStruct it holds users defined data
    attr_accessor :user_data

    attr_accessor :aliases

    #
    # Create a new page
    #
    def initialize(url, params = {})
      @url = url
      @code = params[:code]
      @headers = params[:headers] || {}
      @headers['content-type'] ||= ['']
      @aliases = Array(params[:aka]).compact
      @referer = params[:referer]
      @depth = params[:depth] || 0
      @redirect_to = to_absolute(params[:redirect_to])
      @response_time = params[:response_time]
      @body = params[:body]
      @error = params[:error]
      @fetched = !params[:code].nil?
      @user_data = OpenStruct.new

    end

    #
    # Array of distinct A tag HREFs from the page
    #
    def links
      return @links.to_a unless @links.nil?
      @links = Set.new
      return [] if !doc

      doc.search("//a[@href]").each do |a|
        u = a['href']
        next if u.nil? or u.empty?
        abs = to_absolute(u) rescue next
        @links << abs if in_domain?(abs)
      end
      @links.to_a
    end

    #
    # Nokogiri document for the HTML body
    #
    def doc
      return @doc if @doc
      @doc = Nokogiri::HTML(@body) if @body && html? rescue nil
    end

    #
    # Discard links, a next call of page.links will return an empty array
    #
    def discard_links!
      @links = []
    end

    #
    # Delete the Nokogiri document and response body to conserve memory
    #
    def discard_doc!
      links # force parsing of page links before we trash the document
      @doc = @body = nil
    end

    #
    # Was the page successfully fetched?
    # +true+ if the page was fetched with no error, +false+ otherwise.
    #
    def fetched?
      @fetched
    end

    #
    # The content-type returned by the HTTP request for this page
    #
    def content_type
      headers['content-type'].first
    end

    #
    # Returns +true+ if the page is a HTML document, returns +false+
    # otherwise.
    #
    def html?
      !!(content_type =~ %r{^(text/html|application/xhtml+xml)\b})
    end

    #
    # Returns +true+ if the page is a HTTP redirect, returns +false+
    # otherwise.
    #
    def redirect?
      (300..307).include?(@code)
    end

    #
    # Returns +true+ if the page was not found (returned 404 code),
    # returns +false+ otherwise.
    #
    def not_found?
      404 == @code
    end

    #
    # Base URI from the HTML doc head element
    # http://www.w3.org/TR/html4/struct/links.html#edef-BASE
    #
    def base
      @base = if doc
        href = doc.search('//head/base/@href')
        URI(href.to_s) unless href.nil? rescue nil
      end unless @base
      
      return nil if @base && @base.to_s().empty?
      @base
    end

    #
    # Converts relative URL *link* into an absolute URL based on the
    # location of the page
    #
    def to_absolute(link)
      return nil if link.nil?

      # remove anchor
      link = URI.encode(URI.decode(link.to_s.gsub(/#[a-zA-Z0-9_-]*$/,'')))

      relative = URI(link)
      absolute = base ? base.merge(relative) : @url.merge(relative)

      absolute.path = '/' if absolute.path.empty?

      return absolute
    end

    #
    # Returns +true+ if *uri* is in the same domain as the page, returns
    # +false+ otherwise
    #
    def in_domain?(uri)
      uri.host == @url.host || uri.host == "www.#{@url.host}"
    end

    def to_hash
      {'url' => @url.to_s,
       'headers' => Marshal.dump(@headers),
       'body' => @body,
       'links' => links.map(&:to_s), 
       'code' => @code,
       'depth' => @depth,
       'referer' => @referer.to_s,
       'redirect_to' => @redirect_to.to_s,
       'response_time' => @response_time,
       'fetched' => @fetched,
       'user_data' => @user_data.nil? ? {} : @user_data.marshal_dump
     }
    end

    def to_json
      th = to_hash.dup
      th.each {|k,v| th.delete(k) if v.nil? || (v.respond_to?(:empty?) && v.empty?)}
      th.delete('headers') if content_type.empty?
      th.to_json
    end

    def self.from_hash(hash)
      page = self.new(URI(hash['url']))
      {'@headers' => hash['headers'] ? Marshal.load(hash['headers']) : {'content-type' => ['']},
       '@body'    => hash['body'],
       '@links'   => hash['links'] ? hash['links'].map { |link| URI(link) } : [],
       '@code'    => hash['code'].to_i,
       '@depth'   => hash['depth'].to_i,
       '@referer' => hash['referer'],
       '@redirect_to' => (!!hash['redirect_to'] && !hash['redirect_to'].empty?) ? URI(hash['redirect_to']) : nil,
       '@response_time' => hash['response_time'].to_i,
       '@fetched' => hash['fetched'],
       '@user_data' => hash['user_data'] ? OpenStruct.new(hash['user_data']) : nil
      }.each do |var, value|
        page.instance_variable_set(var, value)
      end
      page
    end

    def self.from_json(json)
      hash = JSON.parse json
      self.from_hash hash
    end
  end
end
