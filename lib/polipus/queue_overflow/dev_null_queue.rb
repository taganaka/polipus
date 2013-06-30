require "thread"
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

      def push data
      end

      def pop(_ = false)
        nil
      end
      
      alias :size  :length
      alias :dec   :pop
      alias :shift :pop
      alias :enc   :push
      alias :<<    :push
    end
  end
end