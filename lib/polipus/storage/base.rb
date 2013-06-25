require "uri"

module Polipus
  module Storage
    class Base
      attr_accessor :include_query_string_in_uuid
      protected
        def uuid page
          @include_query_string_in_uuid || true
          Digest::MD5.hexdigest(@include_query_string_in_uuid ? page.url.to_s : page.url.to_s.gsub(/\?.*$/,'')) 
        end
    end
  end
end