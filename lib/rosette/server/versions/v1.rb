# encoding: UTF-8

java_import java.lang.System
java_import 'java.net.URLClassLoader'

require 'shellwords'

require 'rosette/core'
require 'rosette/server/version'
require 'rosette/server/tools'

module Rosette
  module Server

    class V1 < Grape::API
      include Rosette::Core::Commands
      logger Rosette.logger

      def self.configuration
        @configuration
      end

      def self.set_configuration(configuration)
        @configuration = configuration
        configuration.apply_integrations(self)
      end

      helpers do
        def configuration
          V1.configuration
        end

        def logger
          V1.logger
        end

        def validate_and_execute(command)
          if command.valid?
            begin
              command.execute
            rescue => e
              configuration.error_reporter.report_error(e, get_extra_fields)
              error!({ error: e.message }, 400)
            end
          else
            errors = command.messages.flat_map do |field, messages|
              messages
            end

            error!({ error: errors.first }, 400)
          end
        end

        def get_extra_fields
          { headers: headers, params: get_params }
        end

        def get_params
          request.params.dup.tap { |hash| hash.delete('route_info') }.to_h
        rescue NoMethodError
          {}
        end
      end

      version 'v1', using: :path
      format :json

      resource :locales, { desc: 'Information about configured locales.' } do
        desc 'List configured locales'

        params do
          requires :repo_name, {
            type: String,
            desc: 'The name of the repository to get locales for. Must be configured in the current Rosette config.'
          }
        end

        get do
          configuration.get_repo(params[:repo_name]).locales.map do |locale|
            {
              language: locale.language,
              territory: locale.territory,
              code: locale.code
            }
          end
        end
      end

      desc 'Health endpoint.'
      get :alive do
        true
      end

      # @TODO: remove
      desc 'List configured environment variables. Will be removed soon.'
      get :env do
        ENV.to_h
      end

      # @TODO: remove
      desc 'Show the value for a given java system property.'

      params do
        requires :prop, {
          type: String,
          desc: 'The name of the property to retrieve.'
        }
      end

      get :property do
        [System.getProperty(params[:prop])]
      end

      resource :git, { desc: 'Perform various git-insipired operations on phrases and translations' } do
        #### COMMIT ####

        desc 'Extract phrases from a commit and store them in the datastore.'

        params do
          requires :repo_name, {
            type: String,
            desc: 'The name of the repository to examine. Must be configured in the current Rosette config.'
          }

          requires :ref, {
            type: String, presence: true,
            desc: 'The git ref to commit phrases from. Can be either a git symbolic ref (i.e. branch ' +
              'name) or a git commit id.'
          }
        end

        get :commit do
          validate_and_execute(
            FetchCommand.new(configuration)
              .set_repo_name(params[:repo_name])
          )

          validate_and_execute(
            CommitCommand.new(configuration)
              .set_repo_name(params[:repo_name])
              .set_commit_id(params[:ref])
          )

          validate_and_execute(
            ShowCommand.new(configuration)
              .set_repo_name(params[:repo_name])
              .set_commit_id(params[:ref])
          ).each_with_object({}) do |(state, phrases), ret|
            ret[state] = phrases.size
          end
        end

        #### SHOW ####

        desc 'List the phrases contained in a commit'

        params do
          requires :repo_name, {
            type: String,
            desc: 'The name of the repository to examine. Must be configured in the current Rosette config.'
          }

          requires :ref, {
            type: String, presence: true,
            desc: 'The git ref to list phrases for. Can be either a git symbolic ref (i.e. branch ' +
              'name) or a git commit id.'
          }
        end

        get :show do
          validate_and_execute(
            ShowCommand.new(configuration)
              .set_repo_name(params[:repo_name])
              .set_ref(params[:ref])
          ).each_with_object({}) do |(state, phrases), ret|
            ret[state] = phrases.map(&:to_h)
          end
        end

        #### STATUS ####

        desc 'Translation progress for a given commit'

        params do
          requires :repo_name, {
            type: String,
            desc: 'The name of the repository to examine. Must be configured in the current Rosette config.'
          }

          requires :ref, {
            type: String, presence: true,
            desc: 'The git ref to get the status for. Can be either a git symbolic ref (i.e. branch ' +
              'name) or a git commit id.'
          }
        end

        get :status do
          status = validate_and_execute(
            StatusCommand.new(configuration)
              .set_repo_name(params[:repo_name])
              .set_ref(params[:ref])
          )

          if status
            status
          else
            error!({
              error: 'Commit not processed',
              detail: "Commit #{params[:ref]} hasn't been processed yet"
            }, 500)
          end
        end

        #### DIFF ####

        desc 'Lists the phrases that were added, removed, or changed between two commits'

        params do
          requires :repo_name, {
            type: String,
            desc: 'The name of the repository to examine. Must be configured in the current Rosette config.'
          }

          requires :head_ref, {
            type: String, presence: true,
            desc: 'The git ref to compare against diff_point_ref. This is usually a HEAD (i.e. branch name). ' +
              'Can be either a git symbolic ref (i.e. branch name) or a git commit id.'
          }

          requires :diff_point_ref, {
            type: String, presence: true,
            desc: 'The git ref to compare to head_ref. This is usually master or some common parent. ' +
              'Can be either a git symbolic ref (i.e. branch name) or a git commit id.'
          }

          optional :paths, {
            type: String,
            desc: 'A space-separated list of paths to include in the diff.'
          }
        end

        get :diff do
          validate_and_execute(
            DiffCommand.new(configuration)
              .set_repo_name(params[:repo_name])
              .set_head_ref(params[:head_ref])
              .set_diff_point_ref(params[:diff_point_ref])
              .set_paths(Shellwords.shellsplit(params.fetch(:paths, '')))
          ).each_with_object({}) do |(state, phrases), ret|
            ret[state] = phrases.map(&:to_h)
          end
        end

        #### SNAPSHOT ####

        desc 'Returns the translations for the most recent changes for each file in the repository'

        params do
          requires :repo_name, {
            type: String,
            desc: 'The name of the repository in which to take the snapshot. Must be configured in the ' +
              'current Rosette config.'
          }

          requires :ref, {
            type: String, presence: true,
            desc: 'The git ref to take the snapshot of. Can be either a git symbolic ref (i.e. branch ' +
              'name) or a git commit id.'
          }
        end

        get :snapshot do
          validate_and_execute(
            SnapshotCommand.new(configuration)
              .set_repo_name(params[:repo_name])
              .set_ref(params[:ref])
          ).map(&:to_h)
        end

        #### REPO SNAPSHOT (snapshot without translations) ####

        desc 'Returns the commit ids for the most recent changes for each file in the repository'

        params do
          requires :repo_name, {
            type: String,
            desc: 'The name of the repository in which to take the snapshot. Must be configured in the ' +
              'current Rosette config.'
          }

          requires :ref, {
            type: String, presence: true,
            desc: 'The git ref to take the snapshot of. Can be either a git symbolic ref (i.e. branch ' +
              'name) or a git commit id.'
          }
        end

        get :repo_snapshot do
          validate_and_execute(
            RepoSnapshotCommand.new(configuration)
              .set_repo_name(params[:repo_name])
              .set_ref(params[:ref])
          )
        end
      end

      resource :translations, { desc: 'Perform various operations on translations' } do
        #### ADD TRANSLATION ####

        desc 'Associates a translation with a key or meta key'

        params do
          requires :repo_name, {
            type: String,
            desc: 'The name of the repository the translation belongs to. Must be configured in the ' +
              'current Rosette config.'
          }

          requires :translation, {
            type: String,
            desc: 'The translated text.'
          }

          requires :locale, {
            type: String, presence: true,
            desc: 'The locale of the translated text'
          }

          optional :key, {
            type: String,
            desc: 'The key to associate the translation with. Either key or meta_key must be specified. ' +
              'If key is not specified, meta_key must be. If neither is specified, an error will be returned.'
          }

          optional :meta_key, {
            type: String,
            desc: 'The meta key to associate the translation with. Either key or meta_key must be specified. ' +
              'If meta_key is not specified, key must be. If neither is specified, an error will be returned.'
          }

          requires :ref, {
            type: String,
            desc: 'The git ref to associate the translation with. Can be either a git symbolic ref (i.e. branch ' +
              'name) or a git commit id.'
          }

          at_least_one_of :key, :meta_key  # @TODO: only works with grape master
        end

        post :add_or_update do
          validate_and_execute(
            AddOrUpdateTranslationCommand.new(configuration)
              .set_repo_name(params[:repo_name])
              .set_key(params[:key])
              .set_meta_key(params[:meta_key])
              .set_refs([params[:ref]])
              .set_translation(params[:translation])
              .set_locale(params[:locale])
          ).map do |translation_status|
            {
              status: translation_status[:status],
              translation: translation_status[:translation].to_h
            }
          end
        end

        #### EXPORT ####

        desc 'Retrieve and serialize the phrases and translations for a given ref'

        params do
          requires :repo_name, {
            type: String,
            desc: 'The name of the repository to export translations from. Must be configured in the ' +
              'current Rosette config.'
          }

          requires :ref, {
            type: String,
            desc: 'The git ref to export translations from. Can be either a git symbolic ref (i.e. branch ' +
              'name) or a git commit id.'
          }

          requires :locale, {
            type: String, presence: true,
            desc: 'The locale of the translations to retrieve.'
          }

          requires :serializer, {
            type: String,
            desc: 'The serializer to use to serialize the phrases in the given ref. The serializer must ' +
              'have been configured in the configuration for the repo.'
          }

          optional :base_64_encode, {
            type: Boolean,
            desc: 'If set to true, the serialized phrases will be base-64 encoded. This is often desirable ' +
              'to avoid unexpected encoding issues when transmitting data over the Internet.'
          }

          optional :encoding, {
            type: String,
            desc: 'The text encoding to encode the phrases in before serialization. Any encoding supported ' +
              'by Ruby can be specified, eg. UTF-8, UTF-16, US-ASCII, etc.'
          }

          optional :include_snapshot, {
            type: Boolean,
            desc: 'If true, includes the snapshot (hash of paths to commit ids) that was used to identify the' +
              'phrases and therefore translations in the response.'
          }

          optional :include_checksum, {
            type: Boolean,
            desc: 'If true, includes an MD5 checksum of the exported translations.'
          }
        end

        get :export do
          validate_and_execute(
            ExportCommand.new(configuration)
              .set_repo_name(params[:repo_name])
              .set_ref(params[:ref])
              .set_locale(params[:locale])
              .set_serializer(params[:serializer])
              .set_base_64_encode(params.fetch(:base_64_encode, false))
              .set_encoding(params.fetch(:encoding, Rosette::Core::DEFAULT_ENCODING.to_s))
              .set_include_snapshot(params.fetch(:include_snapshot, false))
              .set_include_checksum(params.fetch(:include_checksum, false))
          )
        end
      end

      add_swagger_documentation api_version: 'v1'
    end

  end
end
