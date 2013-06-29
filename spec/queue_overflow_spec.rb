require "spec_helper"
require "polipus/queue_overflow"

describe Polipus::QueueOverflow do
  before(:all) do
    @queue_overflow  = Polipus::QueueOverflow.mongo_queue(nil, "queue_test")
  end

  before(:each) do
    @queue_overflow.clear
  end

  after(:all) do
    @queue_overflow.clear
  end

  it 'should work' do
    @queue_overflow.empty?.should be_true
    @queue_overflow.pop.should be_nil
    @queue_overflow << "test"
    @queue_overflow.size.should be == 1
    @queue_overflow.pop.should be == "test"
    @queue_overflow.empty?.should be_true
    @queue_overflow.pop.should be_nil
    @queue_overflow.size.should be == 0
  end

  it 'should act as a queue' do
    10.times { |i| @queue_overflow << "message_#{i}" }
    @queue_overflow.size.should be == 10
    @queue_overflow.pop.should be == "message_0"
  end

  it 'should work with complex paylod' do
    a = {'a' => [1,2,3], 'b' => 'a_string'}
    @queue_overflow << a.to_json
    b = @queue_overflow.pop
    JSON.parse(b).should be == a
  end

end
