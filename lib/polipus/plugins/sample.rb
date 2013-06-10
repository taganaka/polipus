module Polipus
  module Plugin
    class Sample
      
      def initialize(options = {})
        
      end

      def on_initialize crawler
        Proc.new {
          @options.each { |k,v| @logger.info {"Polipus configuration: #{k.to_s} => #{v}"} }
        }
      end
      
    end
  end
end