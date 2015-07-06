# encoding: UTF-8
require 'spec_helper'
require 'mongo'
require 'polipus/queue_overflow'
require 'redis-queue'

describe Polipus::QueueOverflow::Manager do
  before(:all) do
    @mongo = Mongo::Client.new(['localhost:27_017'], database: '_test_polipus')
    @mongo['_test_pages'].drop
    @storage = Polipus::Storage.mongo_store(@mongo, '_test_pages')
    @redis_q = Redis::Queue.new('queue_test', 'bp_queue_test', redis: Redis.new)
    @queue_overflow   = Polipus::QueueOverflow.mongo_queue(nil, 'queue_test')
    @redis = Redis.new
    @polipus = flexmock('polipus')
    @polipus.should_receive(:queue_overflow_adapter).and_return(@queue_overflow)
    @polipus.should_receive(:storage).and_return(@storage)
    @polipus.should_receive(:redis).and_return(@redis)
    @polipus.should_receive(:job_name).and_return('___test')
    @polipus.should_receive(:logger).and_return(Logger.new(nil))
    @manager = Polipus::QueueOverflow::Manager.new(@polipus, @redis_q, 10)
  end

  before(:each) do
    @queue_overflow.clear
    @redis_q.clear
    @storage.clear
  end

  after(:all) do
    @queue_overflow.clear
    @redis_q.clear
  end

  it 'should remove 10 items' do
    expect(@manager.perform).to eq([0, 0])
    20.times { |i| @redis_q << page_factory("http://www.user-doo.com/page_#{i}",  code: 200, body: '<html></html>').to_json  }
    expect(@manager.perform).to eq([10, 0])
    expect(@queue_overflow.size).to eq(10)
    expect(@redis_q.size).to eq(10)
  end

  it 'should restore 10 items' do
    expect(@manager.perform).to eq([0, 0])
    10.times { |i| @queue_overflow << page_factory("http://www.user-doo-bla.com/page_#{i}",  code: 200, body: '<html></html>').to_json }
    expect(@manager.perform).to eq([0, 10])
    expect(@queue_overflow.size).to eq(0)
    expect(@redis_q.size).to eq(10)
    expect(@manager.perform).to eq([0, 0])
  end

  it 'should restore 3 items' do
    expect(@manager.perform).to eq([0, 0])
    3.times { |i| @queue_overflow << page_factory("http://www.user-doo-bu.com/page_#{i}",  code: 200, body: '<html></html>').to_json }
    expect(@manager.perform).to eq([0, 3])
    expect(@queue_overflow.size).to eq(0)
    expect(@redis_q.size).to eq(3)
    expect(@manager.perform).to eq([0, 0])
  end

  it 'should restore 0 items' do
    expect(@manager.perform).to eq([0, 0])
    10.times do|i|
      p = page_factory("http://www.user-doo-bu.com/page_#{i}",  code: 200, body: '<html></html>')
      @storage.add p
      @queue_overflow << p.to_json
    end
    expect(@manager.perform).to eq([0, 0])
    expect(@queue_overflow.size).to eq(0)
    expect(@redis_q.size).to eq(0)
    expect(@manager.perform).to eq([0, 0])
  end

  it 'should filter an url based on the spec' do
    @queue_overflow.clear
    @redis_q.clear
    10.times { |i| @queue_overflow << page_factory("http://www.user-doo.com/page_#{i}",  code: 200, body: '<html></html>').to_json  }
    @manager.url_filter do |page|
      page.url.to_s.end_with?('page_0') ? false : true
    end
    expect(@manager.perform).to eq([0, 9])
    expect(@queue_overflow.size).to eq(0)
    expect(@redis_q.size).to eq(9)
    @manager.url_filter do |_page|
      true
    end
  end
end
