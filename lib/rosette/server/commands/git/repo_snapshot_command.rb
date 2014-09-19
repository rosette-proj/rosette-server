# encoding: UTF-8

module Rosette
  module Server
    module Commands

      class RepoSnapshotCommand < GitCommand
        include WithSnapshots
        include WithRepoName
        include WithRef

        def execute
          take_snapshot(get_repo(repo_name).repo, commit_id)
        end
      end

    end
  end
end
