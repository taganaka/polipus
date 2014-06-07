require 'thread'
module Polipus
  module QueueOverflow
    class DevNullQueue
      def initialize
      end

      def length
        0
      end

      def empty?
        true
      end

      def clear
      end

      def push(_data)
      end

      def pop(_ = false)
        nil
      end

      alias_method :size,  :length
      alias_method :dec,   :pop
      alias_method :shift, :pop
      alias_method :enc,   :push
      alias_method :<<,    :push
    end
  end
end
