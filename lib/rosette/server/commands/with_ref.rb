# encoding: UTF-8

module Rosette
  module Server
    module Commands

      module WithRef
        attr_reader :commit_id

        def set_ref(ref_str)
          @commit_id = get_repo(repo_name).repo.get_rev_commit(ref_str).getId.name
          self
        end

        def set_commit_id(commit_id)
          @commit_id = commit_id
          self
        end
      end

    end
  end
end
