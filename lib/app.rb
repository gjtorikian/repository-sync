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

  before do
    # trim trailing slashes
    request.path_info.sub!(/\/$/, '')

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

    @squash = params[:squash]

    # keep some important vars
    process_payload(@payload)
    @destination_hostname = params[:destination_hostname] || 'github.com'
  end

  get '/' do
    'You\'ll want to make a POST to /sync. Check the documentation for more info.'
  end

  post '/sync' do
    Resque.enqueue(CloneJob, @after_sha, @destination_hostname, @destination_repo, @originating_hostname, @originating_repo, @squash)
  end

  helpers Helpers
end
