# encoding: UTF-8

module Rosette
  module Server
    module Commands

      module WithRepoName
        attr_reader :repo_name

        def self.included(base)
          base.validate :repo_name, repo: true
        end

        def set_repo_name(repo_name)
          @repo_name = repo_name
          self
        end
      end

    end
  end
end
