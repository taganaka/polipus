# encoding: UTF-8
require 'polipus'

Polipus.crawler('rubygems', 'http://rubygems.org/') do |crawler|
  # Handle connectivity errors
  # Only runs when there is an error
  crawler.on_page_error do |page|
    # Don't store the page
    page.storable = false
    # Add the URL again to the queue
    crawler.add_to_queue(page)
  end

  # In-place page processing
  # Runs also when there was an error in the page
  crawler.on_page_downloaded do |page|
    # Skip block if there is an error
    return if page.error

    # A nokogiri object
    puts "Page title: '#{page.doc.at_css('title').content}' Page url: #{page.url}"
  end
end
