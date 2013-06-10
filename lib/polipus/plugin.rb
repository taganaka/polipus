module Polipus
  module Plugin
    @@plugins = {}
    def self.register plugin, options = {}
      o = plugin.new(options)
      @@plugins[o.class.name] = o
    end

    def self.plugins
      @@plugins
    end
  end
end