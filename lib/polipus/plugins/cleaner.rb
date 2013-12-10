module Polipus
  module Plugin
    class Cleaner
      
      def initialize(options = {})
        @reset = options[:reset] ||= false
      end

      def on_initialize crawler
        crawler.logger.info {"Cleaner plugin loaded"}
        unless @reset
          crawler.logger.info {"Cleaner plugin is disable, add :reset => true to the plugin if you really know what you are doing"}
          return nil
        end
        crawler.logger.info {"Cleaning all: url_tracker, storage, queue"}
        Proc.new {
          url_tracker.clear
          storage.clear
          queue_factory.clear
          @options[:queue_overflow_adapter].clear if @options[:queue_overflow_adapter]
        }
      end
    end
  end
end