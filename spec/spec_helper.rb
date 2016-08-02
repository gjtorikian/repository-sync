require 'bundler/setup'
require 'rack/test'
require 'rspec'
require 'webmock/rspec'
require_relative '../lib/app'
require 'resque_spec'
require 'fileutils'

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

def fixture_path(fixture)
  File.expand_path "fixtures/#{fixture}", File.dirname(__FILE__)
end

def fixture(fixture)
  File.open(fixture_path(fixture)).read
end

def temp_repo
  File.expand_path(File.join('spec/fixtures/working.git'))
end

def octokit_version
  Gem.loaded_specs['octokit'].version
end

def tmpdir
  File.expand_path '../tmp', File.dirname(__FILE__)
end

def setup_tmpdir
  FileUtils.rm_rf tmpdir
  FileUtils.mkdir tmpdir
end
