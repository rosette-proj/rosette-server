# encoding: UTF-8

module Rosette
  module Server
    module Commands

      module WithRepoName
        attr_reader :repo_name

        def self.included(base)
          if base.respond_to?(:validate)
            base.validate :repo_name, type: :repo
          end
        end

        def set_repo_name(repo_name)
          @repo_name = repo_name
          self
        end
      end

    end
  end
end
