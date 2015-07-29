# encoding: UTF-8

require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

require 'expert'
Expert.environment.require_all

require 'grape'
require 'json'
require 'pry'
require 'rack/test'
require 'rosette/core'
require 'rosette/data_stores/in_memory_data_store'
require 'tmp-repo'

module Rosette
  def self.logger; end
end

require 'rosette/server'
