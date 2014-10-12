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

          datastore.add_or_update_commit_log(repo_name, commit_id)
          trigger_hooks
        end

        private

        def commit_processor
          @commit_processor ||= Rosette::Core::CommitProcessor.new(configuration)
        end

        def trigger_hooks
          repo_config = get_repo(repo_name)
          repo_config.hooks.fetch(:commit, []).each do |hook_proc|
            hook_proc.call(configuration, repo_config, commit_id)
          end
        end
      end

    end
  end
end
