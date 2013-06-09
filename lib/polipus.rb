require "mongo"
require "redis-queue"
require "polipus/version"
require "polipus/http"
require "polipus/storage/base"
require "polipus/storage/mongo"
require "polipus/url_tracker/bloomfilter"

$redis = Redis.new
$mongo = Mongo::MongoClient.new('localhost', 27017)
trap(:INT) { exit } #I hate ctrl+c's error
module Polipus
  @@storage = Storage::Mongo.new :mongo => $mongo['webcrawler'], 
                                :collection => 'wordpress'

  @@url_tracker = UrlTracker::Bloomfilter.new :size => 1_000_000, 
                                             :error_rate => 0.01, 
                                             :key_name   => 'wordpress',
                                             :driver     => 'lua'
  @@queue = Redis::Queue.new('wordpress','bp_wordpress', :redis => $redis)
  @@queue.clear(true)
  @@url_tracker.clear
  @@storage.clear
  #http://annunci.ebay.it/annunci/auto/novara-annunci-novara/lancia-k-diesel-come-nuova/45834766
  #http://annunci.ebay.it/motori/auto/?p=2
  #@@focus_on = /^\/(annunci\/auto)|(motori\/auto)\/$/i
  @@focus_on = /^\/wordpress\//i
  def self.crawl(options = {})
    
    start_page = Page.new("http://francesco-laurita.info/wordpress/", :referer => '')

    @@queue << start_page.to_json unless @@url_tracker.visited? start_page.url.to_s

    @http = HTTP.new(:verbose => true)

    @@queue.process(true) do |message|
      page = Page.from_json message
      url = page.url.to_s
      #puts "Fetching #{url} r: #{page.referer} d: #{page.depth}"
      page = @http.fetch_page(url, page.referer, page.depth)
      @@storage.add page
      page.links.each do |url_to_visit|
        unless url_to_visit.path.to_s =~ @@focus_on
          next
        end
        
        unless @@url_tracker.visited?(url_to_visit.to_s)
          page_to_visit = Page.new(url_to_visit.to_s, :referer => url, :depth => page.depth + 1)
          @@queue << page_to_visit.to_json
          @@url_tracker.visit url_to_visit.to_s
        end
      end

      true
    end
  end
end

Polipus.crawl