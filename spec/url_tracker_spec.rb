# encoding: UTF-8
require 'spec_helper'
require 'polipus/url_tracker'

describe Polipus::UrlTracker do
  before(:all) do
    @bf  = Polipus::UrlTracker.bloomfilter
    @set = Polipus::UrlTracker.redis_set
  end

  after(:all) do
    @bf.clear
    @set.clear
  end

  it 'should work (bf)' do
    url = 'http://www.asd.com/asd/lol'
    @bf.visit url
    @bf.visited?(url).should be_true
    @bf.visited?('http://www.google.com').should be_false
  end

  it 'should work (redis_set)' do
    url = 'http://www.asd.com/asd/lol'
    @set.visit url
    @set.visited?(url).should be_true
    @set.visited?('http://www.google.com').should be_false
  end
end
