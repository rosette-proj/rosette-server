# encoding: UTF-8

require 'rack'

module Rosette
  module Server
    class Builder
      attr_reader :rosette_config, :url_map

      def initialize
        @url_map = {}
      end

      def mount(path, app)
        @url_map[path] = app
      end

      def to_app
        Rack::URLMap.new(url_map)
      end
    end
  end
end
