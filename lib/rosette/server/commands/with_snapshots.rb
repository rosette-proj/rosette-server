# encoding: UTF-8

module Rosette
  module Server
    module Commands

      module WithSnapshots
        def take_snapshot(repo, commit_id, paths)
          paths = Array(paths)
          rev = repo.get_rev_commit(commit_id)
          factory = snapshot_factory.new(repo, rev)
          factory = factory.filter_by_paths(paths) if paths.size > 0
          snapshot = factory.take_snapshot
          datastore.phrases_by_commits(repo_name, snapshot)
        end

        private

        def snapshot_factory
          Rosette::Core::SnapshotFactory
        end
      end

    end
  end
end