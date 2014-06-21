# encoding: UTF-8
require 'spec_helper'
require 'aws/s3'
require 'polipus/storage/s3_store'
describe Polipus::Storage::S3Store do

  before(:each) do
    @storage = Polipus::Storage.s3_store(
      '_test_pages',

      access_key_id: 'XXXXXXX',
      secret_access_key: 'XXXX'

    )
  end

  after(:each) { @storage.clear }

  it 'should store a page' do

    p = page_factory 'http://www.google.com', code: 200, body: '<html></html>'
    uuid = @storage.add p
    uuid.should be == 'ed646a3334ca891fd3467db131372140'
    @storage.count.should be 1
    p = @storage.get p
    p.url.to_s.should be == 'http://www.google.com'
    p.body.should be == '<html></html>'
    @storage.remove p

  end

  it 'should update a page' do
    p = page_factory 'http://www.google.com', code: 301, body: '<html></html>'
    @storage.add p
    p = @storage.get p
    p.code.should be == 301
    @storage.count.should be == 1
    @storage.remove p
  end

  it 'should iterate over stored pages' do
    10.times { |i| @storage.add page_factory("http://www.google.com/p_#{i}", code: 200, body: "<html>#{i}</html>") }
    @storage.count.should be 10
    @storage.each do |k, _page|
      k.should be =~ /[a-f0-9]{32}/
    end
  end

  it 'should delete a page' do
    p = page_factory 'http://www.google.com', code: 301, body: '<html></html>'
    @storage.add p
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
    storage = Polipus::Storage.s3_store(
        '_test_pages',
        {
          access_key_id: 'XXXXXXX',
          secret_access_key: 'XXXX'
        },
        ['body']
      )
    p = page_factory 'http://www.user-doo.com',  code: 200, body: '<html></html>'
    storage.add p
    p = storage.get p

    p.body.should be_nil
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
    @storage.remove p_other
  end

end
