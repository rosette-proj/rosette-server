# encoding: UTF-8

module Rosette
  module Server
    module Commands

      class CommitCommand < GitCommand
        include WithRepoName
        include WithRef

        def execute
          commit_processor.process_each_phrase(repo_name, commit_id) do |phrase|
            datastore.store_phrase(repo_name, phrase)
          end
        end

        private

        def commit_processor
          @commit_processor ||= Rosette::Core::CommitProcessor.new(configuration)
        end
      end

    end
  end
end
