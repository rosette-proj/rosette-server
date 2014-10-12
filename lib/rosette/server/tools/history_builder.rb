# encoding: UTF-8

module Rosette
  module Server
    module Tools

      # Walks the commits in a repo and imports phrases for all of them.
      class HistoryBuilder
        attr_reader :config, :error_reporter, :progress_reporter

        def initialize(config, error_reporter = NilErrorReporter.instance, progress_reporter = NilProgressReporter.instance)
          @config = config
          @error_reporter = error_reporter
          @progress_reporter = progress_reporter
        end

        def build_history(repo_name)
          repo = get_repo(repo_name).repo
          commit_count = repo.commit_count

          repo.each_commit.with_index do |rev_commit, idx|
            commit_processor.process_each_phrase(repo_name, rev_commit.getId.name) do |phrase|
              yield phrase if block_given?
              datastore.store_phrase(repo_name, phrase)
            end

            progress_reporter.report_progress(idx + 1, commit_count)
          end

          progress_reporter.report_complete
          nil
        end

        private

        def commit_processor
          @commit_processor ||= CommitProcessor.new(config, error_reporter)
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
