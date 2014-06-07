require 'singleton'
module Polipus
  class SignalHandler
    include Singleton
    attr_accessor :terminated
    attr_accessor :enabled

    def initialize
      self.terminated = false
      self.enabled = false
    end

    def self.enable
      trap(:INT)  do
        exit unless self.enabled?
        terminate
      end
      trap(:TERM) do
        exit unless self.enabled?
        terminate
      end
      instance.enabled = true
    end

    def self.disable
      instance.enabled = false
    end

    def self.terminate
      instance.terminated = true
    end

    def self.terminated?
      instance.terminated
    end

    def self.enabled?
      instance.enabled
    end
  end
end
