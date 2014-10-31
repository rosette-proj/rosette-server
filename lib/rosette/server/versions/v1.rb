# encoding: UTF-8

java_import java.lang.System

require 'shellwords'

require 'rosette/server/version'
require 'rosette/server/tools'
require 'rosette/server/commands'

module Rosette
  module Server

    class V1 < Grape::API
      include Rosette::Server::Commands
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
            command.execute
          else
            errors = command.messages.flat_map do |field, messages|
              messages
            end

            error!({ error: errors.first }, 400)
          end
        end
      end

      version 'v1', using: :path
      format :json

      resource :extractors do
        desc 'List configured extractors'
        get :list do
          configuration
            .repo_configs.each_with_object({}) do |config, ret|
              ret[config.name] = config.extractor_configs.map { |config| config.extractor.class.to_s }
            end
        end
      end

      get :expected_error do
        error!({ error: 'Expected jelly bean error' }, 500)
      end

      get :unexpected_error do
        raise 'Unexpected jelly bean error'
      end

      get :alive do
        true
      end

      # @TODO: remove
      get :env do
        ENV.to_h
      end

      # @TODO: remove
      get :property do
        [System.getProperty(params[:prop])]
      end

      resource :git do
        #### COMMIT ####

        params do
          requires :repo_name, type: String
          requires :ref, type: String, presence: true
        end

        # eventually add commits to a queue
        desc 'Extract phrases from a commit and store them in the datastore.'
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

        params do
          requires :repo_name, type: String
          requires :ref, type: String, presence: true
        end

        desc 'List the phrases contained in a commit'
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

        params do
          requires :repo_name, type: String
          requires :ref, type: String, presence: true
        end

        desc 'Translation progress for a given commit'
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

        params do
          requires :repo_name, type: String
          requires :head_ref, type: String, presence: true
          requires :diff_point_ref, type: String, presence: true
          optional :paths, type: String
        end

        desc 'List phrases added/removed/changed between two commits'
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

        params do
          requires :repo_name, type: String
          requires :ref, type: String, presence: true
        end

        desc 'Returns the translations for the most recent changes for each file in the repository'
        get :snapshot do
          validate_and_execute(
            SnapshotCommand.new(configuration)
              .set_repo_name(params[:repo_name])
              .set_ref(params[:ref])
          ).map(&:to_h)
        end

        #### REPO SNAPSHOT (snapshot without translations) ####

        params do
          requires :repo_name, type: String
          requires :ref, type: String, presence: true
        end

        desc 'Returns the commit ids for the most recent changes for each file in the repository'
        get :repo_snapshot do
          validate_and_execute(
            RepoSnapshotCommand.new(configuration)
              .set_repo_name(params[:repo_name])
              .set_ref(params[:ref])
          )
        end
      end

      resource :translations do
        #### ADD TRANSLATION ####

        params do
          requires :repo_name, type: String
          requires :translation, type: String
          requires :locale, type: String, presence: true
          optional :key, type: String
          optional :meta_key, type: String
          requires :ref, type: String
          at_least_one_of :key, :meta_key  # @TODO: only works with grape master
        end

        desc 'Associates a translation with the key or meta key given'
        get :add_or_update do
          validate_and_execute(
            AddOrUpdateTranslationCommand.new(configuration)
              .set_repo_name(params[:repo_name])
              .set_key(params[:key])
              .set_meta_key(params[:meta_key])
              .set_ref(params[:ref])
              .set_translation(params[:translation])
              .set_locale(params[:locale])
          )
          {}
        end

        #### EXPORT ####

        params do
          requires :repo_name, type: String
          requires :ref, type: String
          requires :locale, type: String, presence: true
          requires :serializer, type: String
          optional :base_64_encode, type: Boolean
          optional :include_snapshot, type: Boolean
        end

        desc 'Retrieve and serialize the phrases and translations for a given ref'
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
          )
        end
      end
    end

  end
end
