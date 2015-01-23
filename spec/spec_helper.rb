
ENV['RACK_ENV'] = 'test'

require 'bundler/setup'
require 'rack/test'
require 'rspec'
require 'webmock/rspec'
require_relative '../lib/app'

WebMock.disable_net_connect!

module RSpecMixin
  include Rack::Test::Methods
  def app
    RepositorySync
  end
end

RSpec.configure do |config|
  # Use color in STDOUT
  config.color = true

  # Run in a random order
  config.order = :random

  config.include RSpecMixin
end

class TestHelper
  include Helpers
end

def with_env(key, value)
  old_env = ENV[key]
  ENV[key] = value
  yield
  ENV[key] = old_env
end

def fixture(path)
  File.open("spec/fixtures/#{path}").read
end
