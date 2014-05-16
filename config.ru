require "./app"
require 'resque/server'

run Rack::URLMap.new \
  "/"       => RepositorySync,
  "/resque" => Resque::Server.new
