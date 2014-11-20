# encoding: UTF-8

require 'concurrent'
require 'progress-reporters'

java_import 'org.eclipse.jgit.treewalk.filter.PathFilter'
java_import 'org.eclipse.jgit.treewalk.TreeWalk'

module Rosette
  module Server
    module Tools

      # Walks the commits in a repo and imports translations for all of them.
      class TranslationHistoryBuilder
        attr_reader :config, :repo_config, :extractor
        attr_reader :error_reporter, :progress_reporter
        attr_reader :path_matcher

        def initialize(options = {})
          @config = options.fetch(:config)
          @repo_config = options.fetch(:repo_config)
          @path_matcher = options.fetch(:path_matcher)
          @extractor = options.fetch(:extractor, repo_config.extractor_configs.first.extractor)
          @error_reporter = options.fetch(:error_reporter, Rosette::Core::NilErrorReporter.instance)
          @progress_reporter = options.fetch(:progress_reporter, ProgressReporters::NilProgressReporter.instance)
        end

        def execute
          commit_count = config.datastore.unique_commit_count(repo_config.name)
          pool = Concurrent::FixedThreadPool.new(10)

          config.datastore.each_unique_commit(repo_config.name) do |commit_id|
            pool << Proc.new do
              process_commit(commit_id)
            end
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

        def deduce_locale(commit_id, path)
          raise NotImplementedError
        end

        def process_commit(commit_id)
          significant_paths_for(commit_id).each_pair do |path, parent_commit_id|
            file_contents = read_object(parent_commit_id, path)

            if locale = deduce_locale(repo_config, parent_commit_id, path)
              trans_count = import_translations(path, file_contents, commit_id, locale)

              config.datastore.add_or_update_commit_log_locale(
                commit_id, locale, trans_count
              )
            end
          end
        rescue => e
          error_reporter.report_error(e)
        end

        def significant_paths_for(commit_id)
          take_snapshot(commit_id).select do |path, parent_commit_id|
            path_matcher.matches?(path)
          end
        end

        def read_object(commit_id, path)
          tree_walk = TreeWalk.new(repo_config.repo.jgit_repo)
          tree_walk.addTree(repo_config.repo.get_rev_commit(commit_id).getTree)
          tree_walk.setFilter(PathFilter.create(path))
          tree_walk.setRecursive(true)
          tree_walk.next
          object_reader = repo_config.repo.jgit_repo.newObjectReader
          bytes = object_reader.open(tree_walk.getObjectId(0)).getBytes
          file_contents = Java::JavaLang::String.new(bytes, 'UTF-8').to_s  # @TODO: encoding??
        end

        def take_snapshot(commit_id)
          Rosette::Core::SnapshotFactory.new
            .set_repo(repo_config.repo)
            .set_start_commit(repo_config.repo.get_rev_commit(commit_id))
            .take_snapshot
        end

        def import_translations(path, file_contents, commit_id, locale)
          trans_counter = 0

          extractor.extract_each_from(file_contents) do |phrase|
            attrs = {
              commit_id: commit_id,
              file: path,
              locale: locale,
              translation: phrase.key,
              meta_key: phrase.meta_key
            }

            begin
              config.datastore.add_or_update_translation(repo_config.name, attrs)
              trans_counter += 1
            rescue Rosette::DataStores::Errors::PhraseNotFoundError => e
              # error_reporter.report_error(e)
            end
          end

          trans_counter
        rescue Rosette::Core::SyntaxError => e
          error_reporter.report_error(e)
          trans_counter
        ensure
          trans_counter
        end
      end

    end
  end
end
