require "spec_helper"
require "mongo"
require "polipus/http"
require "polipus/page"

describe Polipus::HTTP do
  
  it 'should download a page' do

    VCR.use_cassette('http_test') do
      http = Polipus::HTTP.new
      page = http.fetch_page("http://sfbay.craigslist.org/apa/")
      page.should be_an_instance_of(Polipus::Page)
      page.doc.search("title").text.strip.should eq "SF bay area apts/housing for rent classifieds  - craigslist"
    end
  end

  it 'should follow a redirect' do
    VCR.use_cassette('http_test_redirect') do

      http = Polipus::HTTP.new
      page = http.fetch_page("http://greenbytes.de/tech/tc/httpredirects/t300bodyandloc.asis")

      page.should be_an_instance_of(Polipus::Page)
      page.code.should be 200
      page.url.to_s.should eq "http://greenbytes.de/tech/tc/httpredirects/300.txt"
      page.body.strip.should eq "You have reached the target\r\nof a 300 redirect."
      page.fetched_at.should_not be_nil
    end
  end

end