# encoding: UTF-8
module Polipus
  module QueueOverflow
    class Worker
      def initialize(manager)
        @logger  = manager.polipus.logger
        @delay   = manager.polipus.options[:queue_overflow_manager_check_time]
        @adapter = manager.polipus.queue_overflow_adapter
        @manager = manager
      end

      def run
        @logger.info { 'Overflow::Worker::run' }
        loop do
          @logger.info { 'Overflow Manager: cycle started' }
          removed, restored = @manager.perform
          @logger.info { "Overflow Manager: items removed=#{removed}, items restored=#{restored}, items stored=#{@adapter.size}" }
          sleep @delay
          break if SignalHandler.terminated?
        end
      end
    end
  end
end
