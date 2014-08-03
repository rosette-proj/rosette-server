# encoding: UTF-8

module Rosette
  module Server
    module Commands

      class DiffCommand < DiffBaseCommand
        attr_reader :head_commit_id, :diff_point_commit_id, :paths

        include WithRepoName

        def set_head_commit_id(head_commit_id)
          @head_commit_id = head_commit_id
          self
        end

        def set_head_ref(head_ref)
          @head_commit_id = get_repo(repo_name).repo.get_rev_commit(head_ref).getId.name
          self
        end

        def set_diff_point_commit_id(diff_point_commit_id)
          @diff_point_commit_id = diff_point_commit_id
          self
        end

        def set_diff_point_ref(diff_point_ref)
          @diff_point_commit_id = get_repo(repo_name).repo.get_rev_commit(diff_point_ref).getId.name
          self
        end

        def set_paths(paths)
          @paths = paths
          self
        end

        def execute
          repo = get_repo(repo_name).repo
          entries = repo.diff(head_commit_id, diff_point_commit_id, paths)
          head_phrases = take_snapshot(repo, head_commit_id, entries.map(&:getNewPath))
          diff_point_phrases = take_snapshot(repo, diff_point_commit_id, entries.map(&:getOldPath))
          compare(head_phrases, diff_point_phrases)
        end
      end

    end
  end
end
