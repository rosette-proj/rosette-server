# encoding: UTF-8

module Rosette
  module Server
    module Commands
      class DiffEntry

        attr_reader :phrase, :state, :old_phrase

        def initialize(phrase, state, old_phrase = nil)
          @phrase = phrase
          @state = state
          @old_phrase = old_phrase
        end

        def to_h
          phrase.to_h.tap do |hash|
            hash[:old_key] = old_phrase.key if old_phrase
          end
        end

      end
    end
  end
end
