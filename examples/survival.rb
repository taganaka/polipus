require "polipus"

Polipus.crawler("rubygems","http://rubygems.org/") do |crawler|
  # In-place page processing
  crawler.on_page_downloaded do |page|
    # A nokogiri object
    puts "Page title: '#{page.doc.css('title').text}' Page url: #{page.url}"
  end
end