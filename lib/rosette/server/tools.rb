# encoding: UTF-8

module Rosette
  module Server
    module Tools
      autoload :HistoryBuilder,                 'rosette/server/tools/history_builder'
      autoload :TranslationHistoryBuilder,      'rosette/server/tools/translation_history_builder'
      autoload :RailsTranslationHistoryBuilder, 'rosette/server/tools/rails_translation_history_builder'
    end
  end
end
