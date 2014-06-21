# encoding: UTF-8
require 'spec_helper'
require 'mongo'
require 'polipus/storage/mongo_store'
describe Polipus::Storage::MongoStore do
  before(:all)do
    @mongo = Mongo::Connection.new('localhost', 27_017, pool_size: 15, pool_timeout: 5).db('_test_polipus')
    @mongo['_test_pages'].drop
    @storage = Polipus::Storage.mongo_store(@mongo, '_test_pages')
  end

  after(:all) do
    @mongo['_test_pages'].drop
  end

  after(:each) do
    @mongo['_test_pages'].drop
  end

  it 'should store a page' do
    p = page_factory 'http://www.google.com', code: 200, body: '<html></html>'
    uuid = @storage.add p
    uuid.should be == 'ed646a3334ca891fd3467db131372140'
    @storage.count.should be 1
    @mongo['_test_pages'].count.should be 1
    p = @storage.get p
    p.url.to_s.should be == 'http://www.google.com'
    p.body.should be == '<html></html>'
  end

  it 'should update a page' do
    p = page_factory 'http://www.google.com', code: 301, body: '<html></html>'
    @storage.add p
    p = @storage.get p
    p.code.should be == 301
    @mongo['_test_pages'].count.should be 1
  end

  it 'should iterate over stored pages' do
    @storage.each do |k, page|
      k.should be == 'ed646a3334ca891fd3467db131372140'
      page.url.to_s.should be == 'http://www.google.com'
    end
  end

  it 'should delete a page' do
    p = page_factory 'http://www.google.com', code: 301, body: '<html></html>'
    @storage.remove p
    @storage.get(p).should be_nil
    @storage.count.should be 0
  end

  it 'should store a page removing a query string from the uuid generation' do
    p = page_factory 'http://www.asd.com/?asd=lol', code: 200, body: '<html></html>'
    p_no_query = page_factory 'http://www.asd.com/?asdas=dasda&adsda=1', code: 200, body: '<html></html>'
    @storage.include_query_string_in_uuid = false
    @storage.add p
    @storage.exists?(p_no_query).should be_true
    @storage.remove p
  end

  it 'should store a page removing a query string from the uuid generation no ending slash' do
    p = page_factory 'http://www.asd.com?asd=lol', code: 200, body: '<html></html>'
    p_no_query = page_factory 'http://www.asd.com', code: 200, body: '<html></html>'
    @storage.include_query_string_in_uuid = false
    @storage.add p
    @storage.exists?(p_no_query).should be_true
    @storage.remove p
  end

  it 'should store a page with user data associated' do
    p = page_factory 'http://www.user.com',  code: 200, body: '<html></html>'
    p.user_data.name = 'Test User Data'
    @storage.add p
    @storage.exists?(p).should be_true
    p = @storage.get(p)
    p.user_data.name.should be == 'Test User Data'
    @storage.remove p
  end

  it 'should honor the except parameters' do
    storage = Polipus::Storage.mongo_store(@mongo, '_test_pages', ['body'])
    p = page_factory 'http://www.user-doo.com',  code: 200, body: '<html></html>'
    storage.add p
    p = storage.get p
    p.body.should be_empty
    storage.clear
  end

  it 'should return false if a doc not exists' do
    @storage.include_query_string_in_uuid = false
    p_other  = page_factory 'http://www.asdrrrr.com', code: 200, body: '<html></html>'
    @storage.exists?(p_other).should be_false
    @storage.add p_other
    @storage.exists?(p_other).should be_true
    p_other  = page_factory 'http://www.asdrrrr.com?trk=asd-lol', code: 200, body: '<html></html>'
    @storage.exists?(p_other).should be_true
    @storage.include_query_string_in_uuid = true
    @storage.exists?(p_other).should be_false

  end

  it 'should set page.fetched_at based on the id creation' do
    storage = Polipus::Storage.mongo_store(@mongo, '_test_pages')
    p = page_factory 'http://www.user-doojo.com',  code: 200, body: '<html></html>'
    storage.add p
    p.fetched_at.should be_nil
    p = storage.get p
    p.fetched_at.should_not be_nil
  end

  it 'should NOT set page.fetched_at if already present' do
    storage = Polipus::Storage.mongo_store(@mongo, '_test_pages')
    p = page_factory 'http://www.user-doojooo.com',  code: 200, body: '<html></html>'
    p.fetched_at = 10
    storage.add p
    p = storage.get p
    p.fetched_at.should be 10
  end

end
