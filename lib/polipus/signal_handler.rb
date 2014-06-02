require "singleton"
module Polipus
  class SignalHandler

    include Singleton
    attr_accessor :terminated

    def initialize
      self.terminated = false
    end

    def self.enable
      trap(:INT)  {
        self.terminate
      }
      trap(:TERM) {
        self.terminate
      }
    end

    def self.terminate
      self.instance.terminated = true
    end

    def self.terminated?
      self.instance.terminated
    end

  end
end