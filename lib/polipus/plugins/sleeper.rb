module Polipus
  module Plugin
    class Sleeper
      def initialize(options = {})
        @delay = options[:delay] ||= 1
      end

      def on_initialize(crawler)
        crawler.logger.info { "Sleeper plugin loaded, sleep for #{@delay} after each request" }
        proc do
          # Set to 1 the number of threads
          @options[:workers] = 1
        end
      end

      def on_message_processed(_crawler)
        sleep @delay
      end
    end
  end
end
