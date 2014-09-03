# encoding: UTF-8

require 'stringio'
require 'base64'

module Rosette
  module Server
    module Commands

      class ExportCommand < GitCommand
        attr_reader :locale, :serializer, :base_64_encode, :encoding, :include_snapshot

        include WithRepoName
        include WithRef
        include WithLocale

        include WithSnapshots

        validate :serializer, serializer: true
        validate :encoding, encoding: true

        def set_serializer(serializer)
          @serializer = serializer
          self
        end

        def set_base_64_encode(should_encode)
          @base_64_encode = should_encode
          self
        end

        # eg. UTF-8, UTF-16BE, etc
        def set_encoding(encoding)
          @encoding = encoding
          self
        end

        def set_include_snapshot(should_include_snapshot)
          @include_snapshot = should_include_snapshot
          self
        end

        def execute
          stream = StringIO.new
          repo_config = get_repo(repo_name)
          serializer_instance = get_serializer_instance(repo_config, stream)
          snapshot = take_snapshot(repo_config.repo, commit_id)
          translation_count = 0

          each_translation(repo_config, snapshot) do |trans|
            serializer_instance.write_translation(trans)
            translation_count += 1
          end

          serializer_instance.close

          params = {
            payload: encode(stream.string),
            encoding: serializer_instance.encoding.to_s,
            translation_count: translation_count,
            base_64_encoded: base_64_encode
          }

          if include_snapshot
            params.merge!(snapshot: snapshot)
          end

          params
        end

        private

        def encode(string)
          if base_64_encode
            Base64.encode64(string)
          else
            string
          end
        end

        def get_serializer_instance(repo_config, stream)
          serializer_config = repo_config.get_serializer_config(serializer)
          serializer_config.klass.new(stream, encoding)
        end

        def each_translation(repo_config, snapshot)
          datastore.translations_by_commits(repo_name, snapshot) do |trans_chunk|
            trans_chunk.each do |trans|
              yield trans
            end
          end
        end
      end

    end
  end
end
