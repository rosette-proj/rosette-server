# encoding: UTF-8

module Rosette
  module Server
    module Commands

      class CommitCommand < Command
        include WithRepoName
        include WithRef

        def execute
          process_each_phrase do |phrase|
            datastore.store_phrase(repo_name, phrase)
          end
        end

        private

        # can throw: org.eclipse.jgit.errors.MissingObjectException
        def process_each_phrase
          if block_given?
            repo_config = get_repo(repo_name)
            commit = repo_config.repo.get_rev_commit(commit_id)
            repo_config.repo.rev_diff_with_parent(commit).each do |diff_entry|
              process_diff_entry(diff_entry, repo_config) do |phrase|
                yield phrase
              end
            end
          else
            to_enum(__method__, repo_name, commit_id)
          end
        end

        def process_diff_entry(diff_entry, repo_config)
          repo_config.get_extractor_configs(diff_entry.getNewPath).each do |extractor_config|
            source_code = read_object_from_entry(diff_entry, repo_config, extractor_config)
            extractor_config.extractor.extract_each_from(source_code) do |phrase|
              phrase.file = diff_entry.getNewPath
              phrase.commit_id = commit_id
              yield phrase
            end
          end
        end

        def read_object_from_entry(diff_entry, repo_config, extractor_config)
          bytes = repo_config.repo.read_object_bytes(diff_entry.getNewId.toObjectId)
          Java::JavaLang::String.new(bytes, extractor_config.encoding.to_s).to_s
        end
      end

    end
  end
end
