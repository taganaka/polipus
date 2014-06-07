module Polipus
  module Plugin
    class Sample
      def initialize(_options = {})
      end

      def on_initialize(_crawler)
        proc do
          @options.each { |k, v| @logger.info { "Polipus configuration: #{k} => #{v}" } }
        end
      end
    end
  end
end
