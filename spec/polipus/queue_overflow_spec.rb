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
      q.empty?.should be_true
      q.pop.should be_nil
      q << 'test'
      q.size.should be == 1
      q.pop.should be == 'test'
      q.empty?.should be_true
      q.pop.should be_nil
      q.size.should be == 0
      q.empty?.should be_true
    end

  end

  it 'should act as a queue' do
    [@queue_overflow, @queue_overflow_capped, @queue_overflow_uniq].each do |q|
      10.times { |i| q << "message_#{i}" }
      q.size.should be == 10
      q.pop.should be == 'message_0'
    end

  end

  it 'should work with complex paylod' do
    [@queue_overflow, @queue_overflow_capped, @queue_overflow_uniq].each do |q|
      a = { 'a' => [1, 2, 3], 'b' => 'a_string' }
      q << a.to_json
      b = q.pop
      JSON.parse(b).should be == a
    end

  end

  it 'should honor max items if it is capped' do
    30.times { |i| @queue_overflow_capped << "message_#{i}" }
    @queue_overflow_capped.size.should be == 20
    @queue_overflow_capped.pop.should be == 'message_10'
  end

  it 'should contains only unique items' do
    20.times { @queue_overflow_uniq << 'A' }
    20.times { @queue_overflow_uniq << 'B' }
    @queue_overflow_uniq.size.should be == 2
  end

end
