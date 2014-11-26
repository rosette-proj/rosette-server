# encoding: UTF-8

require 'concurrent'

module Rosette
  module Server
    module Tools

      # Walks the commits in a repo and imports phrases for all of them.
      class HistoryBuilder
        THREAD_POOL_SIZE = 10

        attr_reader :config, :repo_config
        attr_reader :error_reporter, :progress_reporter

        def initialize(options = {})
          @config = options.fetch(:config)
          @repo_config = options.fetch(:repo_config)
          @error_reporter = options.fetch(:error_reporter, Rosette::Core::NilErrorReporter.instance)
          @progress_reporter = options.fetch(:progress_reporter, ProgressReporters::NilProgressReporter.instance)
        end

        def execute
          commit_count = repo_config.repo.commit_count
          pool = Concurrent::FixedThreadPool.new(THREAD_POOL_SIZE)

          repo_config.repo.each_commit.with_index do |rev_commit, idx|
            pool << Proc.new { process_commit(rev_commit) }
          end

          pool.shutdown
          last_completed_count = 0

          while pool.shuttingdown?
            current_completed_count = pool.completed_task_count

            if current_completed_count > last_completed_count
              progress_reporter.report_progress(
                current_completed_count, commit_count
              )
            end

            last_completed_count = current_completed_count
          end

          progress_reporter.report_progress(
            pool.completed_task_count, commit_count
          )

          progress_reporter.report_complete
        end

        protected

        def process_commit(rev_commit)
          commit_id = rev_commit.getId.name
          phrase_counter = 0

          commit_processor.process_each_phrase(repo_config.name, commit_id) do |phrase|
            phrase_counter += 1
            config.datastore.store_phrase(repo_config.name, phrase)
          end

          config.datastore.add_or_update_commit_log(
            repo_config.name, commit_id,
            Time.at(rev_commit.getCommitTime),
            Rosette::DataStores::PhraseStatus::UNTRANSLATED,
            phrase_counter
          )
        rescue => e
          error_reporter.report_error(e)
        end

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
