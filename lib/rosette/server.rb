# encoding: UTF-8

require 'java'
require 'grape'
require 'shellwords'

require 'rosette/server/config'
require 'rosette/server/queues'
require 'rosette/server/data_stores'
require 'rosette/server/version'

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
          CommitCommand.new(Rosette::Server.configuration)
            .set_repo_name(params[:repo_name])
            .set_commit_id(params[:ref])
            .execute
        end

        #### SHOW ####

        params do
          requires :repo_name, type: String
          requires :ref, type: String, present: true
        end

        desc 'List the phrases contained in a commit'
        get :show do
          # this should eventually read from a data store instead of directly from the repo
          ShowCommand.new(Rosette::Server.configuration)
            .set_repo_name(params[:repo_name])
            .set_ref(params[:ref])
            .execute
            .each_with_object({}) do |(state, phrases), ret|
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
          DiffCommand.new(Rosette::Server.configuration)
            .set_repo_name(params[:repo_name])
            .set_head_ref(params[:head_ref])
            .set_diff_point_ref(params[:diff_point_ref])
            .set_paths(Shellwords.shellsplit(params.fetch(:paths, '')))
            .execute
            .each_with_object({}) do |(state, phrases), ret|
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
          SnapshotCommand.new(Rosette::Server.configuration)
            .set_repo_name(params[:repo_name])
            .set_ref(params[:ref])
            .execute
            .map(&:to_h)
        end
      end
    end

  end
end
