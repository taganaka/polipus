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
      expect(page).to be_an_instance_of(Polipus::Page)
      expect(page.doc.search('title').text.strip).to eq 'SF bay area apts/housing for rent classifieds  - craigslist'
      expect(page.fetched_at).not_to be_nil
      expect(page.fetched?).to be_truthy
    end
  end

  it 'should follow a redirect' do
    VCR.use_cassette('http_test_redirect') do

      http = Polipus::HTTP.new
      page = http.fetch_page('http://greenbytes.de/tech/tc/httpredirects/t300bodyandloc.asis')

      expect(page).to be_an_instance_of(Polipus::Page)
      expect(page.code).to be 200
      expect(page.url.to_s).to eq 'http://greenbytes.de/tech/tc/httpredirects/300.txt'
      expect(page.body.strip).to eq "You have reached the target\r\nof a 300 redirect."
    end
  end

  describe 'proxy settings' do

    it 'should set proxy correctly using a procedure' do
      http = Polipus::HTTP.new(proxy_host: -> _con { '127.0.0.0' }, proxy_port: -> _con { 8080 })
      expect(http.proxy_host).to eq '127.0.0.0'
      expect(http.proxy_port).to be 8080
    end

    it 'should set proxy correctly using shorthand method' do
      http = Polipus::HTTP.new(proxy_host_port: -> _con { ['127.0.0.0', 8080] })
      expect(http.proxy_host_port).to eq ['127.0.0.0', 8080]
    end

    it 'should set proxy w/ auth correctly using shorthand method' do
      http = Polipus::HTTP.new(proxy_host_port: -> _con { ['127.0.0.0', 8080, 'a', 'b'] })
      expect(http.proxy_host_port).to eq ['127.0.0.0', 8080, 'a', 'b']
    end

    it 'should set proxy settings' do
      http = Polipus::HTTP.new(proxy_host: '127.0.0.0', proxy_port:  8080, proxy_user: 'a', proxy_pass: 'b')
      expect(http.proxy_port).to be 8080
      expect(http.proxy_host).to eq '127.0.0.0'
      expect(http.proxy_user).to eq 'a'
      expect(http.proxy_pass).to eq 'b'
    end

  end

  describe 'compressed content handling' do

    it 'should decode gzip content' do
      VCR.use_cassette('gzipped_on') do
        http = Polipus::HTTP.new(logger: Logger.new(STDOUT))
        page = http.fetch_page('http://www.whatsmyip.org/http-compression-test/')
        expect(page.doc.css('.gzip_yes')).not_to be_empty
      end
    end

    it 'should decode deflate content' do
      http = Polipus::HTTP.new(logger: Logger.new(STDOUT))
      page = http.fetch_page('http://david.fullrecall.com/browser-http-compression-test?compression=deflate-http')
      expect(page.headers.fetch('content-encoding').first).to eq 'deflate'
      expect(page.body.include?('deflate-http')).to be_truthy
    end

  end

  describe 'staled connections' do

    it 'should refresh a staled connection' do
      VCR.use_cassette('http_tconnection_max_hits') do
        http = Polipus::HTTP.new(connection_max_hits: 1, logger: Logger.new(STDOUT))
        http.class.__send__(:attr_reader, :connections)
        http.class.__send__(:attr_reader, :connections_hits)
        http.fetch_page('https://www.yahoo.com/')
        expect(http.connections['www.yahoo.com'][443]).not_to be_nil
        old_conn = http.connections['www.yahoo.com'][443]
        expect(http.connections_hits['www.yahoo.com'][443]).to be 1

        http.fetch_page('https://www.yahoo.com/tech/expectant-parents-asked-the-internet-to-name-their-83416450388.html')
        expect(http.connections_hits['www.yahoo.com'][443]).to be 1
        expect(http.connections['www.yahoo.com'][443]).not_to be old_conn
      end
    end

  end

  describe 'cookies' do

    it 'should handle cookies correctly' do
      VCR.use_cassette('http_cookies') do
        http = Polipus::HTTP.new(accept_cookies: true)
        http.fetch_page 'http://www.whatarecookies.com/cookietest.asp'
        expect(http.accept_cookies?).to be_truthy
        expect(http.cookie_jar.cookies(URI('http://www.whatarecookies.com/cookietest.asp'))).not_to be_empty
      end
    end

  end

  describe 'net errors' do
    it 'should handle net errors correctly' do
      VCR.use_cassette('http_errors') do
        http = Polipus::HTTP.new(open_timeout: 1, read_timeout: 1)
        expect(http.fetch_page('http://www.wrong-domain.lol/').error).not_to be_nil
      end
    end
  end

end
