# encoding: UTF-8

require 'grape'
require 'rosette/server/versions/v1'

class Server < Grape::API
  mount Rosette::Server::V1
end
