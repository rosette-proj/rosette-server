# encoding: UTF-8

module Rosette
  module Server
    module Commands

      module WithNonMergeRef
        include WithRef

        def self.included(base)
          if base.respond_to?(:validate)
            base.validate :commit_str, {
              type: :commit, allow_merge_commit: false
            }
          end
        end
      end

    end
  end
end
