# encoding: UTF-8

module Rosette
  module Server
    module Commands

      # the base class for commands that need to calculate diffs (eg. diff, show)
      class DiffBaseCommand < GitCommand
        protected

        include WithSnapshots

        def ensure_commits_have_been_processed(snapshot)
          snapshot.each_pair do |file, commit_id|
            unless datastore.commit_log_exists?(repo_name, commit_id)
              raise Errors::UnprocessedCommitError,
                "Commit #{commit_id} has not been processed yet."
            end
          end
        end

        def compare(head_phrases, diff_point_phrases)
          partitioned_head_phrases = partition_phrases(head_phrases)
          partitioned_diff_point_phrases = partition_phrases(diff_point_phrases)
          join_diffs(
            key_diff(partitioned_head_phrases, partitioned_diff_point_phrases),
            meta_key_diff(partitioned_head_phrases, partitioned_diff_point_phrases)
          )
        end

        def join_diffs(diff1, diff2)
          # we don't care about :unmodified, so leave it out
          [:added, :removed, :modified].each_with_object({}) do |state, ret|
            ret[state] = diff1[state] + diff2[state]
          end
        end

        def key_diff(partitioned_head_phrases, partitioned_diff_point_phrases)
          diff = Hash.new { |hash, key| hash[key] = [] }

          key_head_to_diff_point(
            partitioned_head_phrases.first,
            partitioned_diff_point_phrases.first
          ) do |phrase, state, old_phrase|
            diff[state] << DiffEntry.new(phrase, state, old_phrase)
          end

          key_diff_point_to_head(
            partitioned_head_phrases.first,
            partitioned_diff_point_phrases.first
          ) do |phrase, state, old_phrase|
            diff[state] << DiffEntry.new(phrase, state, old_phrase)
          end

          diff
        end

        def key_head_to_diff_point(head_phrases, diff_point_phrases)
          if block_given?
            head_phrases.each do |head_phrase|
              phrase = diff_point_phrases.find do |diff_point_phrase|
                diff_point_phrase.key == head_phrase.key &&
                  diff_point_phrase.file == head_phrase.file
              end

              state = phrase ? :unmodified : :added
              yield head_phrase, state
            end
          else
            to_enum(__method__, head_phrases, diff_point_phrases)
          end
        end

        def key_diff_point_to_head(head_phrases, diff_point_phrases)
          if block_given?
            diff_point_phrases.each do |diff_point_phrase|
              phrase = head_phrases.find do |head_phrase|
                head_phrase.key == diff_point_phrase.key &&
                  head_phrase.file == diff_point_phrase.file
              end

              unless phrase
                yield diff_point_phrase, :removed
              end
            end
          else
            to_enum(__method__, head_phrases, diff_point_phrases)
          end
        end

        def meta_key_diff(partitioned_head_phrases, partitioned_diff_point_phrases)
          diff = Hash.new { |hash, key| hash[key] = [] }

          meta_key_head_to_diff_point(
            partitioned_head_phrases.last,
            partitioned_diff_point_phrases.last
          ) do |phrase, state, old_phrase|
            diff[state] << DiffEntry.new(phrase, state, old_phrase)
          end

          meta_key_diff_point_to_head(
            partitioned_head_phrases.last,
            partitioned_diff_point_phrases.last
          ) do |phrase, state, old_phrase|
            diff[state] << DiffEntry.new(phrase, state, old_phrase)
          end

          diff
        end

        # identifies phrases in head that:
        #   are not in diff point ('added')
        #   have the same meta key but different keys as a phrase in diff point ('modified')
        #   are identical to a phrase in diff point ('unmodified')
        def meta_key_head_to_diff_point(head_phrases, diff_point_phrases)
          if block_given?
            # iterate over all head phrases that have meta keys
            head_phrases.each do |head_phrase|
              idx = diff_point_phrases.find_index do |diff_point_phrase|
                diff_point_phrase.meta_key == head_phrase.meta_key &&
                  diff_point_phrase.file == head_phrase.file
              end

              state = if idx
                if diff_point_phrases[idx].key == head_phrase.key
                  :unmodified
                else
                  :modified
                end
              else
                :added
              end

              if state == :modified
                yield head_phrase, state, diff_point_phrases[idx]
              else
                yield head_phrase, state
              end
            end
          else
            to_enum(__method__, head_phrases, diff_point_phrases)
          end
        end

        # identifies phrases in diff point that are not in head ('removed')
        def meta_key_diff_point_to_head(head_phrases, diff_point_phrases)
          if block_given?
            diff_point_phrases.each do |diff_point_phrase|
              idx = head_phrases.find_index do |head_phrase|
                head_phrase.meta_key == diff_point_phrase.meta_key &&
                  head_phrase.file == diff_point_phrase.file
              end

              unless idx
                yield diff_point_phrase, :removed
              end
            end
          else
            to_enum(__method__, head_phrases, diff_point_phrases)
          end
        end

        def partition_phrases(phrases)
          phrases.partition { |ph| ph.index_key == :key }
        end
      end

    end
  end
end
