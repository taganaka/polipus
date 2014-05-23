# encoding: UTF-8
module Polipus
  module Plugin

    @@plugins = {}
    def self.register(plugin, options = {})
      o = plugin.new(options)
      @@plugins[plugin.name] = o
    end

    def self.plugins
      @@plugins
    end

    module Base

      attr_reader :plugins_options
      def initialize(options = {})
        @plugins_options = options
      end

      def self.included(mod)
        puts "#{self} included in #{mod}"
        mod.extend(ClassMethods)
      end

      module ClassMethods

        @@plugin_data = {}

        def plugin_data
          @@plugin_data
        end

        def on_initialize(&block)
          @@plugin_data[__callee__] = block
        end

        def on_crawl_start(&block)
          @@plugin_data[__callee__] = block
        end

        def on_message_received(&block)
          @@plugin_data[__callee__] = block
        end

        def on_before_download(&block)
          @@plugin_data[__callee__] = block
        end

        def on_after_download(&block)
          @@plugin_data[__callee__] = block
        end

        def on_page_stored(&block)
          @@plugin_data[__callee__] = block
        end

        def on_message_processed(&block)
          @@plugin_data[__callee__] = block
        end

        def on_crawl_end(&block)
          @@plugin_data[__callee__] = block
        end
      end

    end

  end
end
