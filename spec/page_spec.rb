require "spec_helper"
require "polipus/page"

describe Polipus::Page do
  let(:page) do
    body = <<EOF
    <html>
      <body>
        <a href="/page/1">1</a>
        <a href="/page/2">2</a>
        <a href="http://www.google.com/page/3">3</a>
        <a href="http://google.com/page/3">4</a>
        <a href="http://not.google.com/page/3">4</a>
      </body>
    </html>
EOF
    Polipus::Page.new 'http://www.google.com/', 
      code: 200, 
      body: body, 
      headers: {'content-type' => ['text/html']}, 
      domain_aliases: %w(www.google.com google.com)
  end

  it 'should be fetched' do
    page.fetched?.should be_true
  end
  
  it 'should honor domain_aliases attribute' do
    page.links.count.should be 4
  end
end
