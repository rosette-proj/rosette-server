# encoding: UTF-8

module Rosette
  module Server
    module Commands

      class FetchCommand < Command
        include WithRepoName

        def execute
          get_repo(repo_name).fetch
        end
      end

    end
  end
end
