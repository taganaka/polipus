require "spec_helper"
require "mongo"
require "polipus/http"
require "polipus/page"

describe Polipus::HTTP do
  
  it 'should download a page' do
    puts "merda"
    VCR.use_cassette('http_test') do
      http = Polipus::HTTP.new
      page = http.fetch_page("http://sfbay.craigslist.org/apa/")
      page.should be_an_instance_of(Polipus::Page)
      page.doc.search("title").text.strip.should be == "SF bay area apts/housing for rent classifieds  - craigslist"
    end
  end
  
end