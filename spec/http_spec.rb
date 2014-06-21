# encoding: UTF-8
require 'spec_helper'
require 'mongo'
require 'polipus/http'
require 'polipus/page'

describe Polipus::HTTP do

  it 'should download a page' do
    VCR.use_cassette('http_test') do
      http = Polipus::HTTP.new
      page = http.fetch_page('http://sfbay.craigslist.org/apa/')
      page.should be_an_instance_of(Polipus::Page)
      page.doc.search('title').text.strip.should eq 'SF bay area apts/housing for rent classifieds  - craigslist'
      page.fetched_at.should_not be_nil
      page.fetched?.should be_true
    end
  end

  it 'should follow a redirect' do
    VCR.use_cassette('http_test_redirect') do

      http = Polipus::HTTP.new
      page = http.fetch_page('http://greenbytes.de/tech/tc/httpredirects/t300bodyandloc.asis')

      page.should be_an_instance_of(Polipus::Page)
      page.code.should be 200
      page.url.to_s.should eq 'http://greenbytes.de/tech/tc/httpredirects/300.txt'
      page.body.strip.should eq "You have reached the target\r\nof a 300 redirect."
    end
  end

  describe 'proxy settings' do

    it 'should set proxy correctly using a procedure' do
      http = Polipus::HTTP.new(proxy_host: -> _con { '127.0.0.0' }, proxy_port: -> _con { 8080 })
      http.proxy_host.should eq '127.0.0.0'
      http.proxy_port.should be 8080
    end

    it 'should set proxy correctly using shorthand method' do
      http = Polipus::HTTP.new(proxy_host_port: -> _con { ['127.0.0.0', 8080] })
      http.proxy_host_port.should eq ['127.0.0.0', 8080]
      http.proxy_port.should be 8080
      http.proxy_host.should eq '127.0.0.0'
    end

    it 'should set proxy settings' do
      http = Polipus::HTTP.new(proxy_host: '127.0.0.0', proxy_port:  8080)
      http.proxy_port.should be 8080
      http.proxy_host.should eq '127.0.0.0'
    end

  end

  describe 'compressed content handling' do

    it 'should decode gzip content' do
      VCR.use_cassette('gzipped_on') do
        http = Polipus::HTTP.new(logger: Logger.new(STDOUT))
        page = http.fetch_page('http://www.whatsmyip.org/http-compression-test/')
        page.doc.css('.gzip_yes').should_not be_empty
      end
    end

    it 'should decode deflate content' do
      http = Polipus::HTTP.new(logger: Logger.new(STDOUT))
      page = http.fetch_page('http://david.fullrecall.com/browser-http-compression-test?compression=deflate-http')
      page.headers.fetch('content-encoding').first.should eq 'deflate'
      page.body.include?('deflate-http').should be_true
    end

  end

  describe 'staled connections' do

    it 'should refresh a staled connection' do
      VCR.use_cassette('http_tconnection_max_hits') do
        http = Polipus::HTTP.new(connection_max_hits: 1, logger: Logger.new(STDOUT))
        http.class.__send__(:attr_reader, :connections)
        http.class.__send__(:attr_reader, :connections_hits)
        http.fetch_page('https://www.yahoo.com/')
        http.connections['www.yahoo.com'][443].should_not be_nil
        old_conn = http.connections['www.yahoo.com'][443]
        http.connections_hits['www.yahoo.com'][443].should be 1

        http.fetch_page('https://www.yahoo.com/tech/expectant-parents-asked-the-internet-to-name-their-83416450388.html')
        http.connections_hits['www.yahoo.com'][443].should be 1
        http.connections['www.yahoo.com'][443].should_not be old_conn
      end
    end

  end

  describe 'cookies' do

    it 'should handle cookies correctly' do
      VCR.use_cassette('http_cookies') do
        http = Polipus::HTTP.new(accept_cookies: true)
        http.fetch_page 'http://www.whatarecookies.com/cookietest.asp'
        http.accept_cookies?.should be_true
        http.cookie_jar.cookies(URI('http://www.whatarecookies.com/cookietest.asp')).should_not be_empty
      end
    end

  end

  describe 'net errors' do
    it 'should handle net errors correctly' do
      VCR.use_cassette('http_errors') do
        http = Polipus::HTTP.new(open_timeout: 1, read_timeout: 1)
        http.fetch_page('http://www.wrong-domain.lol/').error.should_not be_nil
      end
    end
  end

end
