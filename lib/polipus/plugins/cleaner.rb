# encoding: UTF-8
module Polipus
  module Plugin
    class Cleaner
      include Polipus::Plugin::Base

      on_initialize do |plugin_instance|
        if plugin_instance.options[:reset]
          @logger.info { 'Cleaning all: url_tracker, storage, queue' }
          url_tracker.clear
          storage.clear
          queue_factory.clear
          @options[:queue_overflow_adapter].clear if @options[:queue_overflow_adapter]
        else
          @logger.info { 'Cleaner plugin is disable, add :reset => true to the plugin if you really know what you are doing' }
        end
      end

      def plugin_registered
        puts "Plugin #{self.class.name} registered with options: #{plugin_options}"
        @options[:reset] ||= false
      end
    end
  end
end
