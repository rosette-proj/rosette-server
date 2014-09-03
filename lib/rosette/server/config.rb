# encoding: UTF-8

module Rosette
  module Server

    class << self
      attr_reader :configuration

      def configure
        @configuration ||= Rosette::Core::Configurator.new
        yield @configuration
      end
    end

  end
end
