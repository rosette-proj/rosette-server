require 'concurrent'
require 'progress-reporters'

java_import 'org.eclipse.jgit.treewalk.filter.PathFilter'
java_import 'org.eclipse.jgit.treewalk.TreeWalk'

module Rosette
  module Server
    module Tools

      # Walks the commits in a repo and imports translations for all of them.
      class TranslationHistoryBuilder
        THREAD_POOL_SIZE = 10

        attr_reader :config, :repo_config, :extractor_configs
        attr_reader :error_reporter, :progress_reporter
        attr_reader :path_matcher

        def initialize(options = {})
          @config = options.fetch(:config)
          @repo_config = options.fetch(:repo_config)
          @path_matcher = options.fetch(:path_matcher)
          @extractor_configs = options.fetch(:extractors, repo_config.extractor_configs)
          @error_reporter = options.fetch(:error_reporter, Rosette::Core::NilErrorReporter.instance)
          @progress_reporter = options.fetch(:progress_reporter, ProgressReporters::NilProgressReporter.instance)
        end

        def execute
          rev_walk = RevWalk.new(repo_config.repo.jgit_repo).tap do |rev_walk|
            rev_walk.markStart(repo_config.repo.all_heads(rev_walk))
            rev_walk.sort(RevSort::REVERSE)
          end

          rev_iterator = rev_walk.iterator

          diff_finder = Rosette::Core::DiffFinder.new(
            repo_config.repo.jgit_repo, rev_walk
          )

          process_commits(rev_iterator, diff_finder)
        end

        protected

        def process_commits(rev_iterator, diff_finder)
          # source changed
          #   add to list of commits to update
          # target changed
          #   stop iterating and deal with it
          # source AND target changed
          #   both of the above, but retain the commit to use as a source commit next time around

          source_commits = []
          pool = Concurrent::FixedThreadPool.new(THREAD_POOL_SIZE)

          while cur_commit = rev_iterator.next
            diff = diff_finder.diff_with_parent(cur_commit)

            if source_changed?(diff)
              if target_changed?(diff)
                # source AND target changed
                source_commits << cur_commit
                process_changes(pool, source_commits.dup, cur_commit, target_changes(diff))
                source_commits.clear
              else
                # only source changed
                source_commits << cur_commit
              end
            elsif target_changed?(diff)
              # only target changed
              process_changes(pool, source_commits.dup, cur_commit, target_changes(diff))
              source_commits.clear
            end
          end

          pool.shutdown

          last_completed_count = 0

          while pool.shuttingdown?
            current_completed_count = pool.completed_task_count

            if current_completed_count > last_completed_count
              progress_reporter.report_progress(
                current_completed_count, pool.scheduled_task_count
              )
            end

            last_completed_count = current_completed_count
          end

          progress_reporter.report_progress(
            pool.completed_task_count, pool.scheduled_task_count
          )

          progress_reporter.report_complete
        end

        # source means English in most cases
        def source_changed?(diff)
          diff.any? do |entry|
            extractor_configs.any? do |extractor_config|
              extractor_config.matches?(entry.getNewPath)
            end
          end
        end

        def target_changed?(diff)
          diff.any? do |entry|
            path_matcher.matches?(entry.getNewPath)
          end
        end

        # target means foreign language(s) in most cases
        def target_changes(diff)
          diff.each_with_object([]) do |entry, paths|
            if path_matcher.matches?(entry.getNewPath)
              paths << entry.getNewPath
            end
          end
        end

        def process_changes(pool, source_commits, target_commit, target_change_arr)
          pool << Proc.new do
            object_reader = repo_config.repo.jgit_repo.newObjectReader

            tree_walk = TreeWalk.new(repo_config.repo.jgit_repo).tap do |tree_walk|
              tree_walk.addTree(target_commit.getTree)
              tree_walk.setFilter(PathFilterGroup.createFromStrings(target_change_arr))
              tree_walk.setRecursive(true)
            end

            while tree_walk.next
              bytes = object_reader.open(tree_walk.getObjectId(0)).getBytes
              file_contents = Java::JavaLang::String.new(bytes, 'UTF-8').to_s  # @TODO: encoding??
              path = tree_walk.getPathString
              commit_ids = source_commits.map do |source_commit|
                source_commit.getId.name
              end

              if locale = deduce_locale(repo_config, path)
                commit_ids.each do |commit_id|
                  trans_count = import_translations(path, file_contents, commit_id, locale)

                  config.datastore.add_or_update_commit_log_locale(
                    commit_id, locale, trans_count
                  )
                end
              end
            end
          end
        end

        def deduce_locale(commit_id, path)
          raise NotImplementedError
        end

        def import_translations(path, file_contents, commit_id, locale)
          trans_counter = 0

          extractor_configs.each do |extractor_config|
            extractor_config.extractor.extract_each_from(file_contents) do |phrase|
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
                # These can occur frequently since there may be translations
                # that have no corresponding phrase. Reporting them was turning
                # out to make the logs really noisy.
              end
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
