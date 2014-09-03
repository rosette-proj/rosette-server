# encoding: UTF-8

module Rosette
  module Server
    module Commands

      module WithLocale
        attr_reader :locale

        def self.included(base)
          base.validate :locale, locale: true
        end

        def set_locale(locale_code)
          @locale = locale_code
          self
        end
      end

    end
  end
end
