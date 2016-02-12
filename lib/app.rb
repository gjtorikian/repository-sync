begin
  require 'dotenv'
rescue LoadError
end

require 'sinatra/base'
require 'json'
require 'redis'
require 'openssl'
require 'base64'

require_relative '../config/redis'
require_relative './helpers'
require_relative './cloner'

class RepositorySync < Sinatra::Base
  set :root, File.dirname(__FILE__)
  Dotenv.load if Sinatra::Base.development?

  configure do
    configure_redis
  end

  SUPPORTED_SYNC_METHODS = ['squash', 'merge', 'replace_contents']

  get '/' do
    'You\'ll want to make a POST to /sync. Check the documentation for more info.'
  end

  post '/sync' do
    # trim trailing slashes
    request.path_info.sub!(/\/$/, '')

    # ensure there's a payload
    request.body.rewind
    payload_body = request.body.read.to_s
    halt 400, 'Missing body payload!' if payload_body.nil? || payload_body.empty?

    # ensure signature is correct
    github_signature = request.env['HTTP_X_HUB_SIGNATURE']
    halt 400, 'Signatures didn\'t match!' unless signatures_match?(payload_body, github_signature)

    @destination_repo = params[:dest_repo]
    halt 400, 'Missing `dest_repo` argument' if @destination_repo.nil?

    @payload = JSON.parse(payload_body)
    halt 202, "Payload was not for master, was for #{@payload['ref']}, aborting." unless master_branch?(@payload)

    # Support ?squash parameter for backwards compatibility.
    if params[:squash] && params[:sync_method].nil?
      params[:sync_method] = "squash"
    end

    @sync_method = params[:sync_method] || "merge"
    halt 400, "sync_method #{@sync_method} not supported" unless SUPPORTED_SYNC_METHODS.include?(@sync_method)

    # keep some important vars
    process_payload(@payload)
    @destination_hostname = params[:destination_hostname] || 'github.com'

    @default_branch = params[:default_branch]

    Resque.enqueue(CloneJob, @committers, @after_sha, @destination_hostname, @destination_repo, @originating_hostname, @originating_repo, @default_branch, @sync_method)
  end

  helpers Helpers
end
