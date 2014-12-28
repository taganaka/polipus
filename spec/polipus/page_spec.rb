# encoding: UTF-8
require 'spec_helper'
require 'polipus/page'

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
                      headers: { 'content-type' => ['text/html'] },
                      domain_aliases: %w(www.google.com google.com)
  end

  it 'should be fetched' do
    expect(page.fetched?).to be_truthy
  end

  it 'should honor domain_aliases attribute' do
    expect(page.links.count).to be 4
  end

  context 'page expiring' do
    let(:page) do
      Polipus::Page.new 'http://www.google.com/',
                        code: 200,
                        body: '',
                        headers: { 'content-type' => ['text/html'] },
                        domain_aliases: %w(www.google.com google.com),
                        fetched_at: (Time.now.to_i - 30)
    end

    it 'should be marked at expired' do
      expect(page.expired?(20)).to be_truthy
    end

    it 'should NOT be marked at expired' do
      expect(page.expired?(60)).to be_falsey
    end
  end

  context 'page error' do
    let(:page) do
      Polipus::Page.new 'http://www.google.com/', error: 'an error'
    end

    it 'should serialize an error' do
      expect(page.to_hash['error']).to eq 'an error'
    end
  end

  context 'page code' do
    it 'should identify HTTPSuccess code' do
      expect(Polipus::Page.new('http://www.google.com/', code: 201).success?).to be_truthy
      expect(Polipus::Page.new('http://www.google.com/', code: 404).success?).to be_falsey
    end
  end
end
