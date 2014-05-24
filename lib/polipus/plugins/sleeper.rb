# encoding: UTF-8
module Polipus
  module Plugin
    class Sleeper

      include Polipus::Plugin::Base

      on_initialize do |plugin_instance|
        @options[:workers] = 1
        @logger.info {"#{self.class.name}: options: #{plugin_instance.plugin_options}"}
      end

      on_message_processed do |plugin_instance|
        sleep plugin_instance.plugin_options[:delay]
      end

      def plugin_registered
        puts "Plugin #{self.class.name} registered with options: #{plugin_options}"
      end
      
    end
  end
end
