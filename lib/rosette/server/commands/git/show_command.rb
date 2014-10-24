# encoding: UTF-8

module Rosette
  module Server
    module Commands

      # A show is really just a diff with your parent
      class ShowCommand < DiffBaseCommand
        include WithRepoName
        include WithNonMergeRef

        def execute
          repo = get_repo(repo_name).repo

          child_snapshot = take_snapshot(repo, commit_id)
          child_phrases = datastore.phrases_by_commits(repo_name, child_snapshot).to_a
          paths = child_phrases.map(&:file).uniq

          parent_commit = repo.find_first_non_merge_parent(commit_id)
          parent_snapshot = take_snapshot(repo, parent_commit.getId.name, paths)
          parent_phrases = datastore.phrases_by_commits(repo_name, parent_snapshot).to_a

          compare(child_phrases, parent_phrases)
        end
      end

    end
  end
end
