require "spec_helper"
require "mongo"
require "polipus/storage/mongo_store"
describe Polipus::Storage::MongoStore do
  before(:all)do
    @mongo = Mongo::Connection.new("localhost", 27017, :pool_size => 15, :pool_timeout => 5).db('_test_polipus')
    @mongo['_test_pages'].drop
    @storage = Polipus::Storage.mongo_store(@mongo, '_test_pages')
  end

  after(:all) do
    @mongo['_test_pages'].drop
  end

  it 'should store a page' do
    p = page_factory 'http://www.google.com', :code => 200, :body => '<html></html>'
    @storage.add p
    @storage.count.should be 1
    @mongo['_test_pages'].count.should be 1
    p = @storage.get p
    p.url.to_s.should be == 'http://www.google.com'
    p.body.should be == '<html></html>'
  end

  it 'should update a page' do
    p = page_factory 'http://www.google.com', :code => 301, :body => '<html></html>'
    @storage.add p
    p = @storage.get p
    p.code.should be == 301
    @mongo['_test_pages'].count.should be 1
  end

  it 'should iterate over stored pages' do
    @storage.each do |k, page|
      k.should be == "ed646a3334ca891fd3467db131372140"
      page.url.to_s.should be == 'http://www.google.com'
    end
  end

  it 'should delete a page' do
    p = page_factory 'http://www.google.com', :code => 301, :body => '<html></html>'
    @storage.remove p
    @storage.get(p).should be_nil
    @storage.count.should be 0
  end
end