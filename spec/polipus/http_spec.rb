# encoding: UTF-8
require 'spec_helper'
require 'mongo'
require 'polipus/http'
require 'polipus/page'

describe Polipus::HTTP do
  it 'should download a page' do
    VCR.use_cassette('http_test') do
      http = Polipus::HTTP.new
      user_data = {
        'mydata' => 'myvalue'
      }
      page = http.fetch_page('http://sfbay.craigslist.org/apa/', '', 0, user_data)
      expect(page).to be_an_instance_of(Polipus::Page)
      expect(page.doc.search('title').text.strip).to eq 'SF bay area apts/housing for rent classifieds  - craigslist'
      expect(page.fetched_at).not_to be_nil
      expect(page.fetched?).to be_truthy
      expect(page.user_data).to eq user_data
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

  describe 'random user_agent' do
    context 'when user_agent is string' do
      it '#user_agent' do
        http = Polipus::HTTP.new(open_timeout: 1, read_timeout: 1, user_agent: 'Googlebot')
        expect(http.user_agent).to eq('Googlebot')
      end
    end

    context 'when user_agent is list' do
      let(:user_agents) do
        ['Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/535.1 (KHTML, like Gecko) Chrome/13.0.782.24 Safari/535.1',
         'Mozilla/5.0 (Windows NT 6.0) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.874.120 Safari/535.2',
         'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/535.7 (KHTML, like Gecko) Chrome/16.0.912.36 Safari/535.7',
         'Mozilla/5.0 (Windows; U; Windows NT 6.0 x64; en-US; rv:1.9pre) Gecko/2008072421 Minefield/3.0.2pre',
         'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.10) Gecko/2009042316 Firefox/3.0.10',
         'Mozilla/5.0 (Windows; U; Windows NT 6.0; en-GB; rv:1.9.0.11) Gecko/2009060215 Firefox/3.0.11 (.NET CLR 3.5.30729)',
         'Mozilla/5.0 (Windows; U; Windows NT 6.0; en-US; rv:1.9.1.6) Gecko/20091201 Firefox/3.5.6 GTB5',
         'Mozilla/5.0 (Windows; U; Windows NT 5.1; tr; rv:1.9.2.8) Gecko/20100722 Firefox/3.6.8 ( .NET CLR 3.5.30729; .NET4.0E)'
        ]
      end

      it '#user_agent' do
        http = Polipus::HTTP.new(open_timeout: 1, read_timeout: 1, user_agent: user_agents)
        expect(user_agents).to include(http.user_agent)
      end
    end
  end
end
