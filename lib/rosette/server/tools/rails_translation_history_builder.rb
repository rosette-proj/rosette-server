# encoding: UTF-8

module Rosette
  module Server
    module Tools

      class RailsTranslationHistoryBuilder < TranslationHistoryBuilder
        protected

        def deduce_locale(repo_config, path)
          locale_str = File.basename(path).chomp(File.extname(path))
          if locale_obj = find_locale(repo_config, locale_str)
            locale_obj.code
          end
        end

        def find_locale(repo_config, locale_str)
          repo_config.locales.find do |obj|
            locale_str == obj.code || locale_str == obj.language
          end
        end
      end

    end
  end
end
