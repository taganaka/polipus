# encoding: UTF-8
require 'spec_helper'
require 'polipus/queue_overflow'

describe Polipus::QueueOverflow do
  before(:all) do
    @queue_overflow        = Polipus::QueueOverflow.mongo_queue(nil, 'queue_test')
    @queue_overflow_capped = Polipus::QueueOverflow.mongo_queue_capped(nil, 'queue_test_c', max: 20)
    @queue_overflow_uniq   = Polipus::QueueOverflow.mongo_queue(nil, 'queue_test_u', ensure_uniq: true)
  end

  before(:each) do
    @queue_overflow.clear
    @queue_overflow_capped.clear
    @queue_overflow_uniq.clear
  end

  after(:all) do
    @queue_overflow.clear
    @queue_overflow_uniq.clear
    @queue_overflow_capped.clear
  end

  it 'should work' do
    [@queue_overflow, @queue_overflow_capped, @queue_overflow_uniq].each do |q|
      expect(q.empty?).to be_truthy
      expect(q.pop).to be_nil
      q << 'test'
      expect(q.size).to eq(1)
      expect(q.pop).to eq('test')
      expect(q.empty?).to be_truthy
      expect(q.pop).to be_nil
      expect(q.size).to eq(0)
      expect(q.empty?).to be_truthy
    end
  end

  it 'should act as a queue' do
    [@queue_overflow, @queue_overflow_capped, @queue_overflow_uniq].each do |q|
      10.times { |i| q << "message_#{i}" }
      expect(q.size).to eq(10)
      expect(q.pop).to eq('message_0')
    end
  end

  it 'should work with complex paylod' do
    [@queue_overflow, @queue_overflow_capped, @queue_overflow_uniq].each do |q|
      a = { 'a' => [1, 2, 3], 'b' => 'a_string' }
      q << a.to_json
      b = q.pop
      expect(JSON.parse(b)).to eq(a)
    end
  end

  it 'should honor max items if it is capped' do
    30.times { |i| @queue_overflow_capped << "message_#{i}" }
    expect(@queue_overflow_capped.size).to eq(20)
    expect(@queue_overflow_capped.pop).to eq('message_10')
  end

  it 'should contains only unique items' do
    20.times { @queue_overflow_uniq << 'A' }
    20.times { @queue_overflow_uniq << 'B' }
    expect(@queue_overflow_uniq.size).to eq(2)
  end
end
