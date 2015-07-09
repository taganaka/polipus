# encoding: UTF-8
require 'spec_helper'
require 'mongo'
require 'polipus/storage/mongo_store'
describe Polipus::Storage::MongoStore do
  before(:all)do
    @mongo = Mongo::Client.new(['localhost:27_017'], database: '_test_polipus')
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
    expect(uuid).to eq('ed646a3334ca891fd3467db131372140')
    expect(@storage.count.to_i).to be 1
    expect(@mongo['_test_pages'].find.count.to_i).to be 1
    p = @storage.get p
    expect(p.url.to_s).to eq('http://www.google.com')
    expect(p.body).to eq('<html></html>')
  end

  it 'should update a page' do
    p = page_factory 'http://www.google.com', code: 301, body: '<html></html>'
    @storage.add p
    p = @storage.get p
    expect(p.code).to eq(301)
    expect(@mongo['_test_pages'].find.count.to_i).to be 1
  end

  it 'should iterate over stored pages' do
    @storage.each do |k, page|
      expect(k).to eq('ed646a3334ca891fd3467db131372140')
      expect(page.url.to_s).to eq('http://www.google.com')
    end
  end

  it 'should delete a page' do
    p = page_factory 'http://www.google.com', code: 301, body: '<html></html>'
    @storage.remove p
    expect(@storage.get(p)).to be_nil
    expect(@storage.count.to_i).to be 0
  end

  it 'should store a page removing a query string from the uuid generation' do
    p = page_factory 'http://www.asd.com/?asd=lol', code: 200, body: '<html></html>'
    p_no_query = page_factory 'http://www.asd.com/?asdas=dasda&adsda=1', code: 200, body: '<html></html>'
    @storage.include_query_string_in_uuid = false
    @storage.add p
    expect(@storage.exists?(p_no_query)).to be_truthy
    @storage.remove p
  end

  it 'should store a page removing a query string from the uuid generation no ending slash' do
    p = page_factory 'http://www.asd.com?asd=lol', code: 200, body: '<html></html>'
    p_no_query = page_factory 'http://www.asd.com', code: 200, body: '<html></html>'
    @storage.include_query_string_in_uuid = false
    @storage.add p
    expect(@storage.exists?(p_no_query)).to be_truthy
    @storage.remove p
  end

  it 'should store a page with user data associated' do
    p = page_factory 'http://www.user.com',  code: 200, body: '<html></html>'
    p.user_data.name = 'Test User Data'
    @storage.add p
    expect(@storage.exists?(p)).to be_truthy
    p = @storage.get(p)
    expect(p.user_data.name).to eq('Test User Data')
    @storage.remove p
  end

  it 'should honor the except parameters' do
    storage = Polipus::Storage.mongo_store(@mongo, '_test_pages', ['body'])
    p = page_factory 'http://www.user-doo.com',  code: 200, body: '<html></html>'
    storage.add p
    p = storage.get p
    expect(p.body).to be_nil
    storage.clear
  end

  it 'should return false if a doc not exists' do
    @storage.include_query_string_in_uuid = false
    p_other  = page_factory 'http://www.asdrrrr.com', code: 200, body: '<html></html>'
    expect(@storage.exists?(p_other)).to be_falsey
    @storage.add p_other
    expect(@storage.exists?(p_other)).to be_truthy
    p_other  = page_factory 'http://www.asdrrrr.com?trk=asd-lol', code: 200, body: '<html></html>'
    expect(@storage.exists?(p_other)).to be_truthy
    @storage.include_query_string_in_uuid = true
    expect(@storage.exists?(p_other)).to be_falsey
  end

  it 'should set page.fetched_at based on the id creation' do
    storage = Polipus::Storage.mongo_store(@mongo, '_test_pages')
    p = page_factory 'http://www.user-doojo.com',  code: 200, body: '<html></html>'
    storage.add p
    expect(p.fetched_at).to be_nil
    p = storage.get p
    expect(p.fetched_at).not_to be_nil
  end

  it 'should NOT set page.fetched_at if already present' do
    storage = Polipus::Storage.mongo_store(@mongo, '_test_pages')
    p = page_factory 'http://www.user-doojooo.com',  code: 200, body: '<html></html>'
    p.fetched_at = 10
    storage.add p
    p = storage.get p
    expect(p.fetched_at).to be 10
  end
end
