# encoding: UTF-8

module Rosette
  module Server
    module Tools

      # Walks the commits in a repo and imports translations for all of them.
      class TranslationHistoryBuilder
        attr_reader :config, :extractor, :importer, :error_reporter, :progress_reporter

        def initialize(config, extractor, error_reporter = NilErrorReporter.instance, progress_reporter = NilProgressReporter.instance)
          @config = config
          @error_reporter = error_reporter
          @progress_reporter = progress_reporter
          @extractor = extractor
        end

        # Yields the current commit and expects a map of locales to object_ids.
        # Eg. { de: { 'config/locales/de.yml' => '98a898d988f787098ddacf89ffc89' } }
        def build_translation_history(repo_name)
          if block_given?
            repo = get_repo(repo_name).repo
            commit_count = datastore.unique_commit_count(repo_name)

            datastore.each_unique_commit(repo_name).with_index do |commit_id, idx|
              locale_object_hash = yield commit_id

              locale_object_hash.each_pair do |locale, object_ids|
                object_ids.each_pair do |file, object_id|
                  bytes = repo.read_object_bytes(object_id)
                  file_contents = Java::JavaLang::String.new(bytes, 'UTF-8').to_s

                  import_translations(
                    repo_name, extractor, file, file_contents, commit_id, locale
                  )
                end
              end

              progress_reporter.report_progress(idx + 1, commit_count)
            end

            progress_reporter.report_complete
            nil
          else
            to_enum(__method__, repo_name, start)
          end
        end

        private

        # this of course assumes translations can be imported from a flat file
        def import_translations(repo_name, extractor, file, file_contents, commit_id, locale)
          extractor.extract_each_from(file_contents) do |phrase|
            attrs = {
              commit_id: commit_id,
              file: file,
              locale: locale,
              translation: phrase.key,
              meta_key: phrase.meta_key
            }

            begin
              datastore.add_translation(repo_name, attrs)
            rescue Rosette::DataStores::Errors::PhraseNotFoundError
            end
          end
        end

        def get_repo(name)
          config.get_repo(name)
        end

        def datastore
          config.datastore
        end
      end

    end
  end
end
