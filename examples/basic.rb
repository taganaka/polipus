require "polipus"
require "mongo"
require "polipus/plugins/cleaner"
# Define a Mongo connection
mongo = Mongo::Connection.new(:pool_size => 15, :pool_timeout => 5).db('crawler')

# Override some default options
options = {
  #Redis connection
  :redis_options => {
    :host => 'localhost',
    :db   => 5, 
    :driver => 'hiredis'
  },
  # Page storage: pages is the name of the collection where
  # pages will be stored
  :storage    => Polipus::Storage.mongo_store(mongo, 'pages'),
  # Use your custom user agent
  :user_agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9) AppleWebKit/537.71 (KHTML, like Gecko) Version/7.0 Safari/537.71",
  # Use 5 threads
  :workers    => 5,
  # Logs goes to the crawler.log file
  :logger     => Logger.new(STDOUT)
}
Polipus::Plugin.register Polipus::Plugin::Cleaner, reset:true
starting_urls = ["http://rubygems.org/gems"]

# Crawl the entire rubygems's site
# Polipus.crawler('polipus-rubygems', starting_urls, options)

Polipus.crawler('polipus-rubygems', starting_urls, options) do |crawler|
  # Ignore urls pointing to a gem file
  crawler.skip_links_like(/\.gem$/)
  # Ignore urls pointing to an atom feed
  crawler.skip_links_like(/\.atom$/)
  # Ignore urls containing /versions/ path
  crawler.skip_links_like(/\/versions\//)

  # Adding some metadata to a page
  # The metadata will be stored on mongo
  crawler.on_before_save do |page|
    page.user_data.processed = false
  end

  # In-place page processing
  crawler.on_page_downloaded do |page|
    # A nokogiri object
    puts "Page title: #{page.doc.css('title').text}"
  end

  # Do a nifty stuff at the end of the crawling session
  crawler.on_crawl_end do 
    # Gong.bang(:loudly)
  end
end



