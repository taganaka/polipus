require 'polipus'

options = {
  user_agent: 'Googlebot', # Act as Google bot
  obey_robots_txt: true # Follow /robots.txt rules if any
}

Polipus.crawler('rubygems', 'http://rubygems.org/', options) do |crawler|
  
  crawler.on_page_downloaded do |page|
    puts "Page title: '#{page.doc.at_css('title').content}' Page url: #{page.url}"
  end
end
