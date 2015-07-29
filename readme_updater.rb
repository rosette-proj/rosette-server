# encoding: UTF-8

require 'rosette/core'
require 'rosette/server'
require 'rack/test'
require 'json'
require 'erb'

class ApiElement
  attr_reader :swagger_hash

  def initialize(swagger_hash)
    @swagger_hash = swagger_hash
  end

  def summary
    operation['summary']
  end

  def parameters
    @parameters ||= operation['parameters'].map do |param|
      Parameter.new(param)
    end
  end

  def path
    swagger_hash['path']
  end

  protected

  def operation
    swagger_hash['operations'].first
  end
end

class Parameter < ApiElement
  FIELDS = %w(name description type required)

  def each_field
    if block_given?
      FIELDS.each do |field|
        yield(field, swagger_hash[field])
      end
    else
      to_enum(__method__)
    end
  end
end

class ApiNamespace < ApiElement
  def endpoint?
    false
  end

  # try to turn the path into a nice namespace name
  # eg turn "/locales.{format}" into "Locales"
  def name
    base = swagger_hash['path'].match(/\/?([\w\/]+)\./).captures.first
    base.sub(/\A(\w)/) { $1.upcase }
  end

  def description
    swagger_hash['description']
  end
end

class ApiEndpoint < ApiElement
  def endpoint?
    true
  end
end

class ReadmeUpdater
  class << self

    STARTING_LEVEL = 2
    EXCLUDE = [/alive/, /swagger_doc/]

    include Rack::Test::Methods

    def update_readme
      File.open(output_file, 'w+') do |f|
        f.write(
          strip_leading_whitespace(
            ERB.new(template_contents).result(binding)
          )
        )
      end
    end

    def each_api_element(&block)
      each_api_element_in('/v1/swagger_doc', STARTING_LEVEL, &block)
    end

    protected

    # Removes leading whitespace and extraneous carriage returns. If you
    # actually want a CR or some extra spaces, prefix the line with "->".
    def strip_leading_whitespace(str)
      str.gsub(/^(\s+)/, '').gsub(/^->/, '')
    end

    def each_api_element_in(path, level, &block)
      JSON.parse(get(path).body)['apis'].each do |api|
        unless exclude?(api['path'])
          if api.include?('operations')
            yield(ApiEndpoint.new(api), level)
          else
            yield(ApiNamespace.new(api), level)
            each_api_element_in(
              "/v1/swagger_doc#{interpolate(api['path'])}", level + 1, &block
            )
          end
        end
      end
    end

    def exclude?(path)
      EXCLUDE.any? { |re| path =~ re }
    end

    def interpolate(path, params = { format: 'json' })
      path.gsub(/\{(\w+)\}/) { params[$1.to_sym] }
    end

    def app
      @app ||= Rosette::Server::ApiV1.new(configuration)
    end

    def configuration
      @config ||= Rosette.build_config do; end
    end

    def template_contents
      File.read(template_file)
    end

    def template_file
      File.expand_path('../README.md.erb', __FILE__)
    end

    def output_file
      File.expand_path('../README.md', __FILE__)
    end

  end
end
