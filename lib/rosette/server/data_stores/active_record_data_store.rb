# encoding: UTF-8

# be sure to include 'activerecord' in your gemfile
require 'active_record'

module Rosette
  module Server
    module DataStores

      class ActiveRecordDataStore
        class Phrase < ActiveRecord::Base
          def to_h
            { key: key, meta_key: meta_key, file: file, commit_id: commit_id }
          end

          def self.[](column)
            arel_table[column]
          end
        end

        def initialize(connection_options = {})
          ActiveRecord::Base.establish_connection(
            connection_options
          )
        end

        def store_phrase(repo_name, phrase)
          phrase = model.where(
            repo_name: repo_name,
            key: phrase.key,
            meta_key: phrase.meta_key,
            file: phrase.file,
            commit_id: phrase.commit_id
          ).first_or_initialize
          phrase.save
        end

        def phrases_by_commit(repo_name, commit_id, file = nil)
          # Rather than create a bunch of Rosette::Core::Phrases, just return
          # the ActiveRecord objects, which respond to the same methods.
          params = { repo_name: repo_name, commit_id: commit_id }
          params[:file] = file if file
          model.where(params)
        end

        # commit_id_map is a hash of commit_ids to file paths
        def phrases_by_commits(repo_name, commit_id_map)
          if commit_id_map.is_a?(Array)
            model.where(repo_name: repo_name).where(
              phrases_by_commit_arr(commit_id_map)
            )
          else
            each_phrase_condition_slice(commit_id_map).flat_map do |conditions|
              model.where(repo_name: repo_name).where(conditions)
            end
          end
        end

        private

        def phrases_by_commit_arr(arr)
          model[:commit_id].in(commit_id_map)
        end

        def each_phrase_condition_slice(commit_id_map)
          if block_given?
            each_phrase_slice(commit_id_map, 50) do |slice|
              conditions = slice.inject(nil) do |rel, (file, commit_id)|
                pair = model[:file].eq(file).and(model[:commit_id].eq(commit_id))
                rel ? rel.or(pair) : pair
              end

              yield conditions
            end
          else
            to_enum(__method__, commit_id_map)
          end
        end

        def each_phrase_slice(hash, size)
          if block_given?
            hash.each_with_index.inject({}) do |ret, ((key, val), idx)|
              if idx > 0 && idx % size == 0
                yield ret
                {}
              else
                ret[key] = val
                ret
              end
            end
          else
            to_enum(__method__, hash, size)
          end
        end

        def model
          self.class::Phrase
        end
      end

    end
  end
end
