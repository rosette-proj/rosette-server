# encoding: UTF-8

# be sure to include 'threaded' in your gemfile
require 'threaded'

module Rosette
  module Server
    module Queues

      class MemoryQueue
        def enqueue(job, *args)
          Threaded.enqueue(job, *args)
        end

        def stop
          Threaded.stop
        end
      end

    end
  end
end