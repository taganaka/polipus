# encoding: UTF-8
require 'uri'

module Polipus
  module Storage
    class Base
      attr_accessor :include_query_string_in_uuid

      protected

      def uuid(page)
        if @include_query_string_in_uuid.nil?
          @include_query_string_in_uuid = true
        end
        url_to_hash = @include_query_string_in_uuid ? page.url.to_s : page.url.to_s.gsub(/\?.*$/, '')
        Digest::MD5.hexdigest(url_to_hash)
      end
    end
  end
end
