# encoding: UTF-8

java_import 'org.eclipse.jgit.treewalk.filter.PathFilterGroup'
java_import 'org.eclipse.jgit.treewalk.TreeWalk'

module Rosette
  module Server
    module Tools

      class RailsTranslationHistoryBuilder
        attr_reader :config, :locales, :builder

        def initialize(config, locales, extractor, error_reporter = nil, progress_reporter = nil)
          @config = config
          @locales = locales

          @builder = TranslationHistoryBuilder.new(
            config, extractor, error_reporter, progress_reporter
          )
        end

        def build_translation_history(repo_name)
          repo = get_repo(repo_name).repo
          paths = ['config/locales']
          path_filter = PathFilterGroup.createFromStrings(paths)

          builder.build_translation_history(repo_name) do |commit_id|
            snapshot = Rosette::Core::SnapshotFactory.new(repo, repo.get_rev_commit(commit_id))
              .filter_by_paths(paths)
              .filter_by_extensions(['.yml', '.yaml'])
              .take_snapshot

            snapshot.each_with_object({}) do |(file, commit_id), ret|
              tree_walk = TreeWalk.new(repo.jgit_repo)
              tree_walk.addTree(repo.get_rev_commit(commit_id).getTree)
              tree_walk.setFilter(path_filter)
              tree_walk.setRecursive(true)

              each_file_in(tree_walk) do |file|
                locale = file.getNameString.chomp(File.extname(file.getNameString))

                if locales.include?(locale)
                  ret[locale] ||= {}
                  ret[locale][file.getPathString] = file.getObjectId(0)
                end
              end
            end
          end
        end

        private

        def each_file_in(tree_walk)
          if block_given?
            while tree_walk.next
              yield tree_walk
            end
          else
            to_enum(__method__, tree_walk)
          end
        end

        def get_repo(name)
          config.get_repo(name)
        end
      end

    end
  end
end
