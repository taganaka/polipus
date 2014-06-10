# encoding: UTF-8
require 'forwardable'
require 'redis'
require 'redis/connection/hiredis'
require 'redis-queue'
require 'polipus/version'
require 'polipus/http'
require 'polipus/storage'
require 'polipus/url_tracker'
require 'polipus/plugin'
require 'polipus/queue_overflow'
require 'polipus/robotex'
require 'polipus/signal_handler'
require 'polipus/worker'
require 'polipus/polipus_crawler'
require 'thread'
require 'logger'
require 'json'

module Polipus
  def self.crawler(job_name = 'polipus', urls = [], options = {}, &block)
    PolipusCrawler.crawl(job_name, urls, options, &block)
  end
end
