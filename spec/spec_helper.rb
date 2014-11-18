require 'grape'
require 'rack/test'
require 'java'
require 'jbundler'

require 'rosette/core'
require 'rosette/integrations'
require 'rosette/data_stores/in_memory_data_store'
require 'rosette/serializers/yaml-serializer'
require 'rosette/extractors/yaml-extractor'

require 'json'
require 'tmp-repo'

module Rosette
  def self.logger; end
end

require 'rosette/server'




