require 'sinatra/base'
require 'json'
require 'fileutils'
require 'octokit'
require 'resque'
require 'redis'

require './clone_job'

class RepositorySync < Sinatra::Base
  set :root, File.dirname(__FILE__)

  configure do
    if ENV['RACK_ENV'] == "production"
      uri = URI.parse( ENV[ "REDISTOGO_URL" ])
      REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
      Resque.redis = REDIS
    else
      Resque.redis = Redis.new
    end
  end

  before do
    # trim trailing slashes
    request.path_info.sub! %r{/$}, ''
    pass unless %w[update_public update_private].include? request.path_info.split('/')[1]
    # keep some important vars
    @payload = JSON.parse params[:payload]
    @originating_repo = "#{@payload["repository"]["owner"]["name"]}/#{@payload["repository"]["name"]}"
    @destination_repo = params[:dest_repo]
    check_params params
  end

  get "/" do
    "I think you misunderstand how to use this."
  end

  post "/update_public" do
    do_the_work(true)
  end

  post "/update_private" do
    do_the_work(false)
  end

  helpers do

    def check_params(params)
      return halt 500, "Tokens didn't match!" unless valid_token?(params[:token])
      return halt 500, "Missing `dest_repo` argument" if @destination_repo.nil?
      return halt 202, "Payload was not for master, aborting." unless master_branch?(@payload)
    end

    def valid_token?(token)
      return true if Sinatra::Base.development?
      params[:token] == ENV["REPOSITORY_SYNC_TOKEN"]
    end

    def token
      ENV["HUBOT_GITHUB_TOKEN"]
    end

    def master_branch?(payload)
      payload["ref"] == "refs/heads/master"
    end

    def do_the_work(is_public)
      in_tmpdir do |tmpdir|
        Resque.enqueue(CloneJob, tmpdir, token, @destination_repo, @originating_repo, is_public)
      end
    end

    def in_tmpdir
      path = File.expand_path "#{Dir.tmpdir}/repository-sync/repos/#{Time.now.to_i}#{rand(1000)}/"
      FileUtils.mkdir_p path
      puts "Directory created at: #{path}"
      yield path
    ensure
      FileUtils.rm_rf( path ) if File.exists?( path ) && !Sinatra::Base.development?
    end
  end
end
