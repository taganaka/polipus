require "singleton"
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
      trap(:INT)  {
        self.terminate
      }
      trap(:TERM) {
        self.terminate
      }
      self.instance.enabled = true
    end

    def self.terminate
      self.instance.terminated = true
    end

    def self.terminated?
      self.instance.terminated
    end

    def self.enabled?
      self.instance.enabled
    end

  end
end