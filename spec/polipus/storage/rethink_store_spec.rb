# encoding: UTF-8
require 'spec_helper'
require 'polipus/storage/rethink_store'

describe Polipus::Storage::RethinkStore do
  before(:all)do
    @r = RethinkDB::RQL.new
    @rethink = @r.connect(host: 'localhost', port: 28_015, db: 'polipus_spec')
    @r.db_create('polipus_spec').run(@rethink) unless @r.db_list.run(@rethink).include?('polipus_spec')
    @table = 'test_pages'
    @storage = Polipus::Storage.rethink_store(@rethink, @table)
  end

  after(:each) do
    @r.table(@table).delete.run(@rethink)
  end

  it 'should store a page' do
    page = page_factory 'http://www.google.com', code: 200, body: '<html></html>'
    uuid = @storage.add page
    expect(uuid).to eq('ed646a3334ca891fd3467db131372140')
    expect(@storage.count).to eq(1)
    expect(@r.table(@table).count.run(@rethink)).to eq(1)
    page = @storage.get page
    expect(page.url.to_s).to eq('http://www.google.com')
    expect(page.body).to eq('<html></html>')
  end

  it 'should update a page' do
    page = page_factory 'http://www.google.com', code: 301, body: '<html></html>'
    @storage.add page
    page = @storage.get page
    expect(page.code).to eq(301)
    expect(@r.table(@table).count.run(@rethink)).to eq(1)
  end

  it 'should iterate over stored pages' do
    @storage.each do |k, page|
      expect(k).to eq('ed646a3334ca891fd3467db131372140')
      expect(page.url.to_s).to eq('http://www.google.com')
    end
  end

  it 'should delete a page' do
    page = page_factory 'http://www.google.com', code: 301, body: '<html></html>'
    @storage.remove page
    expect(@storage.get(page)).to be_nil
    expect(@storage.count).to be 0
  end

  it 'should store a page removing a query string from the uuid generation' do
    page = page_factory 'http://www.asd.com/?asd=lol', code: 200, body: '<html></html>'
    p_no_query = page_factory 'http://www.asd.com/?asdas=dasda&adsda=1', code: 200, body: '<html></html>'
    @storage.include_query_string_in_uuid = false
    @storage.add page
    expect(@storage.exists?(p_no_query)).to be_truthy
    @storage.remove page
  end

  it 'should store a page removing a query string from the uuid generation no ending slash' do
    page = page_factory 'http://www.asd.com?asd=lol', code: 200, body: '<html></html>'
    p_no_query = page_factory 'http://www.asd.com', code: 200, body: '<html></html>'
    @storage.include_query_string_in_uuid = false
    @storage.add page
    expect(@storage.exists?(p_no_query)).to be_truthy
    @storage.remove page
  end

  it 'should store a page with user data associated' do
    page = page_factory 'http://www.user.com',  code: 200, body: '<html></html>'
    page.user_data.name = 'Test User Data'
    @storage.add page
    expect(@storage.exists?(page)).to be_truthy
    page = @storage.get(page)
    expect(page.user_data.name).to eq('Test User Data')
    @storage.remove page
  end

  it 'should honor the except parameters' do
    storage = Polipus::Storage.rethink_store(@rethink, @table, ['body'])
    page = page_factory 'http://www.user-doo.com',  code: 200, body: '<html></html>'
    storage.add page
    page = storage.get page
    expect(page.body).to be_empty
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
    storage = Polipus::Storage.rethink_store(@rethink, @table)
    page = page_factory 'http://www.user-doojo.com',  code: 200, body: '<html></html>'
    storage.add page
    expect(page.fetched_at).to be_nil
    page = storage.get page
    expect(page.fetched_at).not_to be_nil
  end

  it 'should NOT set page.fetched_at if already present' do
    storage = Polipus::Storage.rethink_store(@rethink, @table)
    page = page_factory 'http://www.user-doojooo.com',  code: 200, body: '<html></html>'
    page.fetched_at = 10
    storage.add page
    page = storage.get page
    expect(page.fetched_at).to be 10
  end
end
