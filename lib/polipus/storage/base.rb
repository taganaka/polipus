require "uri"

module Polipus
  module Storage
    class Base
      protected
        def uuid page
          Digest::MD5.hexdigest(page.url.to_s) 
        end
    end
  end
end