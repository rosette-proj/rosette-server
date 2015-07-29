# encoding: UTF-8

require 'jbundler'
require 'grape'
require 'rack/test'
require 'java'
require 'rosette/core'
require 'rosette/data_stores/in_memory_data_store'
require 'json'
require 'pry'
require 'tmp-repo'

module Rosette
  def self.logger; end
end

require 'rosette/server'




