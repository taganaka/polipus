# encoding: UTF-8
module Polipus
  module Plugin
    class Sample

      include Polipus::Plugin::Base

      on_initialize do |plugin_instance|
        puts 'on_initialize called'
        puts '-------------------------------------'
        @options.each { |k,v| @logger.info { "Polipus configuration: #{k.to_s} => #{v}" } }
        puts '-------------------------------------'
      end

    end
  end
end
