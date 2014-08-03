# encoding: UTF-8

module Rosette
  module Server
    module Commands

      autoload :CommitCommand,   'rosette/server/commands/commit_command'
      autoload :DiffBaseCommand, 'rosette/server/commands/diff_base_command'
      autoload :DiffCommand,     'rosette/server/commands/diff_command'
      autoload :ShowCommand,     'rosette/server/commands/show_command'
      autoload :SnapshotCommand, 'rosette/server/commands/snapshot_command'

      autoload :WithRepoName,    'rosette/server/commands/with_repo_name'
      autoload :WithRef,         'rosette/server/commands/with_ref'
      autoload :WithSnapshots,   'rosette/server/commands/with_snapshots'

      class Command
        attr_reader :configuration

        def initialize(configuration)
          @configuration = configuration
        end

        protected

        def datastore
          configuration.datastore
        end

        def get_repo(name)
          configuration.get_repo(name)
        end
      end

    end
  end
end
