# encoding: UTF-8

module Rosette
  module Server
    module Commands

      autoload :CommitCommand,                 'rosette/server/commands/git/commit_command'
      autoload :DiffBaseCommand,               'rosette/server/commands/git/diff_base_command'
      autoload :DiffCommand,                   'rosette/server/commands/git/diff_command'
      autoload :ShowCommand,                   'rosette/server/commands/git/show_command'
      autoload :StatusCommand,                 'rosette/server/commands/git/status_command'
      autoload :FetchCommand,                  'rosette/server/commands/git/fetch_command'
      autoload :SnapshotCommand,               'rosette/server/commands/git/snapshot_command'
      autoload :RepoSnapshotCommand,           'rosette/server/commands/git/repo_snapshot_command'

      autoload :AddOrUpdateTranslationCommand, 'rosette/server/commands/translations/add_or_update_translation_command'
      autoload :ExportCommand,                 'rosette/server/commands/translations/export_command'

      autoload :WithRepoName,                  'rosette/server/commands/git/with_repo_name'
      autoload :WithRef,                       'rosette/server/commands/git/with_ref'
      autoload :WithSnapshots,                 'rosette/server/commands/git/with_snapshots'
      autoload :DiffEntry,                     'rosette/server/commands/git/diff_entry'
      autoload :WithLocale,                    'rosette/server/commands/translations/with_locale'

      class Command
        attr_reader :configuration

        class << self
          def validate(field, validator_hash)
            validators[field] = instantiate_validators(validator_hash)
          end

          def validators
            @validators ||= {}
          end

          private

          def instantiate_validators(validator_hash)
            validator_hash.each_with_object([]) do |(validator_name, enabled), ret|
              if enabled
                ret << validator_class_for(validator_name).new
              end
            end
          end

          def validator_class_for(validator_name)
            klass = "#{Rosette::Core::StringUtils.camelize(validator_name.to_s)}Validator"
            if Rosette::Core::Validators.const_defined?(klass)
              Rosette::Core::Validators.const_get(klass)
            else
              raise TypeError, "couldn't find #{validator_name} validator"
            end
          end
        end

        def initialize(configuration)
          @configuration = configuration
        end

        def messages
          @messages ||= {}
        end

        def valid?
          raise NotImplementedError, 'please use a Command subclass.'
        end

        protected

        def datastore
          configuration.datastore
        end
      end

      class GitCommand < Command
        def valid?
          self.class.validators.all? do |name, validators|
            validators.all? do |validator|
              valid = validator.valid?(send(name), repo_name, configuration)
              messages[name] = validator.messages unless valid
              valid
            end
          end
        end

        def get_repo(name)
          configuration.get_repo(name)
        end
      end

    end
  end
end
