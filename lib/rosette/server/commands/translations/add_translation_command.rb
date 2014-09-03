# encoding: UTF-8

module Rosette
  module Server
    module Commands

      class AddTranslationCommand < GitCommand
        attr_reader :key, :meta_key, :translation, :locale

        include WithRepoName
        include WithRef
        include WithLocale

        def set_key(key)
          @key = key
          self
        end

        def set_meta_key(meta_key)
          @meta_key = meta_key
          self
        end

        def set_translation(translation)
          @translation = translation
          self
        end

        def execute
          datastore.add_translation(
            repo_name, {
              key: key,
              meta_key: meta_key,
              commit_id: commit_id,
              translation: translation,
              locale: locale
            }
          )
        end
      end

    end
  end
end
