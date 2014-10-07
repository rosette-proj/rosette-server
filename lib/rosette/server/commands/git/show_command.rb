# encoding: UTF-8

module Rosette
  module Server
    module Commands

      # A show is really just a diff with your parent
      class ShowCommand < DiffBaseCommand
        include WithRepoName
        include WithRef

        def execute
          repo = get_repo(repo_name).repo
          rev = repo.get_rev_commit(commit_id)
          parent_commit_ids = repo.parent_ids_of(rev)
          child_phrases = datastore.phrases_by_commit(repo_name, commit_id)
          paths = child_phrases.map(&:file).uniq

          # hopefully the number of parents will only be one or two
          parent_phrases = parent_commit_ids.flat_map do |parent_commit_id|
            datastore.phrases_by_commits(repo_name, take_snapshot(repo, parent_commit_id, paths)).to_a
          end

          compare(child_phrases, parent_phrases)
        end
      end

    end
  end
end
