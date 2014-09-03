# encoding: UTF-8

require 'shellwords'

require 'rosette/server/version'
require 'rosette/server/config'
require 'rosette/server/queues'
require 'rosette/server/data_stores'
require 'rosette/server/tools'
require 'rosette/server/commands'

module Rosette
  module Server

    class V1 < Grape::API
      include Rosette::Server::Commands

      class Present < Grape::Validations::Validator
        def validate_param!(attr_name, params)
          if (params[attr_name] || '').strip.blank?
            raise Grape::Exceptions::Validation, param: @scope.full_name(attr_name), message: 'must not be blank'
          end
        end
      end

      helpers do
        def validate_and_execute(command)
          if command.valid?
            command.execute
          else
            param, messages = command.messages.first
            raise Grape::Exceptions::Validation, param: param, message: messages.first
          end
        end
      end

      version 'v1', using: :path
      format :json

      resource :extractors do
        desc 'List configured extractors'
        get :list do
          Rosette::Server
            .configuration
            .extractor_configs
            .map { |config| config.extractor.class.to_s }
        end
      end

      resource :git do
        #### COMMIT ####

        params do
          requires :repo_name, type: String
          requires :ref, type: String, present: true
        end

        # eventually add commits to a queue
        desc 'Extract phrases from a commit and store them in the datastore.'
        get :commit do
          validate_and_execute(
            CommitCommand.new(Rosette::Server.configuration)
              .set_repo_name(params[:repo_name])
              .set_commit_id(params[:ref])
          )
          {}
        end

        #### SHOW ####

        params do
          requires :repo_name, type: String
          requires :ref, type: String, present: true
        end

        desc 'List the phrases contained in a commit'
        get :show do
          validate_and_execute(
            ShowCommand.new(Rosette::Server.configuration)
              .set_repo_name(params[:repo_name])
              .set_ref(params[:ref])
          ).each_with_object({}) do |(state, phrases), ret|
            ret[state] = phrases.map(&:to_h)
          end
        end

        #### DIFF ####

        params do
          requires :repo_name, type: String
          requires :head_ref, type: String, present: true
          requires :diff_point_ref, type: String, present: true
          optional :paths, type: String
        end

        desc 'List phrases added/removed/changed between two commits'
        get :diff do
          validate_and_execute(
            DiffCommand.new(Rosette::Server.configuration)
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
          requires :ref, type: String, present: true
        end

        desc 'Returns the commit ids for the most recent changes for each file in the repository'
        get :snapshot do
          validate_and_execute(
            SnapshotCommand.new(Rosette::Server.configuration)
              .set_repo_name(params[:repo_name])
              .set_ref(params[:ref])
          ).map(&:to_h)
        end
      end

      resource :translations do
        #### ADD TRANSLATION ####

        params do
          requires :repo_name, type: String
          requires :translation, type: String
          requires :locale, type: String, present: true
          optional :key, type: String
          optional :meta_key, type: String
          requires :ref, type: String
          at_least_one_of :key, :meta_key  # @TODO: only works with grape master
        end

        desc 'Associates a translation with the key or meta key given'
        get :add do
          validate_and_execute(
            AddTranslationCommand.new(Rosette::Server.configuration)
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
          requires :locale, type: String, present: true
          requires :serializer, type: String
          optional :base_64_encode, type: Boolean
          optional :include_snapshot, type: Boolean
        end

        desc 'Retrieve and serialize the phrases and translations for a given ref'
        get :export do
          validate_and_execute(
            ExportCommand.new(Rosette::Server.configuration)
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
