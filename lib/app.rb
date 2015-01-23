require 'sinatra/base'
require 'json'
require 'fileutils'
require 'octokit'
require 'resque'
require 'redis'
require 'openssl'
require 'base64'

require_relative './helpers'
require_relative './clone_job'

class RepositorySync < Sinatra::Base
  set :root, File.dirname(__FILE__)

  configure do
    if ENV['RACK_ENV'] == 'production'
      uri = URI.parse(ENV['REDISTOGO_URL'])
      REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
      Resque.redis = REDIS
    else
      Resque.redis = Redis.new
    end
  end

  before do
    # trim trailing slashes
    request.path_info.sub!(/\/$/, '')
    pass unless %w(update_public update_private).include? request.path_info.split('/')[1]

    # ensure there's a payload
    request.body.rewind
    payload_body = request.body.read.to_s
    halt 500, 'Missing body payload!' if payload_body.nil? || payload_body.empty?

    # ensure signature is correct
    github_signature = request.env['HTTP_X_HUB_SIGNATURE']
    halt 500, 'Signatures didn\'t match!' unless signatures_match?(payload_body, github_signature)

    @destination_repo = params[:dest_repo]
    halt 500, 'Missing `dest_repo` argument' if @destination_repo.nil?

    @payload = JSON.parse(payload_body)
    halt 202, "Payload was not for master, was for #{@payload['ref']}, aborting." unless master_branch?(@payload)

    # keep some important vars
    process_payload(@payload)
    @destination_hostname = params[:destination_hostname] || 'github.com'
  end

  get '/' do
    'I think you misunderstand how to use this.'
  end

  post '/update_public' do
    do_the_work(true)
  end

  post '/update_private' do
    do_the_work(false)
  end

  helpers Helpers
end
