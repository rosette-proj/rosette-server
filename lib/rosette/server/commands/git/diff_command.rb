# encoding: UTF-8

module Rosette
  module Server
    module Commands

      class DiffCommand < DiffBaseCommand
        attr_reader :head_commit_str, :diff_point_commit_str, :paths

        include WithRepoName

        validate :head_commit_str, type: :commit
        validate :diff_point_commit_str, type: :commit

        def set_head_commit_id(head_commit_id)
          @head_commit_str = head_commit_id
          self
        end

        def set_head_ref(head_ref)
          @head_commit_str = head_ref
          self
        end

        def set_diff_point_commit_id(diff_point_commit_id)
          @diff_point_commit_str = diff_point_commit_id
          self
        end

        def set_diff_point_ref(diff_point_ref)
          @diff_point_commit_str = diff_point_ref
          self
        end

        def set_paths(paths)
          @paths = paths
          self
        end

        def head_commit_id
          @head_commit_id ||= get_repo(repo_name)
            .repo.get_rev_commit(head_commit_str)
            .getId
            .name
        end

        def diff_point_commit_id
          @diff_point_commit_id ||= get_repo(repo_name)
            .repo.get_rev_commit(diff_point_commit_str)
            .getId
            .name
        end

        def execute
          repo = get_repo(repo_name).repo
          entries = repo.diff(head_commit_id, diff_point_commit_id, paths)

          head_snapshot = take_snapshot(repo, head_commit_id, entries.map(&:getNewPath))
          ensure_commits_have_been_processed(head_snapshot)
          head_phrases = datastore.phrases_by_commits(repo_name, head_snapshot)

          diff_point_snapshot = take_snapshot(repo, diff_point_commit_id, entries.map(&:getOldPath))
          ensure_commits_have_been_processed(diff_point_snapshot)
          diff_point_phrases = datastore.phrases_by_commits(repo_name, diff_point_snapshot)

          compare(head_phrases, diff_point_phrases)
        end
      end

    end
  end
end
