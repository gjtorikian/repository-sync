require 'sinatra/base'
require 'json'
require 'fileutils'

class RepositorySync < Sinatra::Base
  set :root, File.dirname(__FILE__)

  # "Thin is a supremely better performing web server so do please use it!"
  set :server, %w[thin webrick]

  before do
    # trim trailing slashes
    request.path_info.sub! %r{/$}, ''
    # keep some important vars
    @token = params[:token]
    @payload = JSON.parse params[:payload]
    @originating_repo = "#{@payload["repository"]["owner"]["name"]}/#{@payload["repository"]["name"]}"
  end

  TEMP_REPO_PREFIX = "/tmp/repository-sync/repos"

  get "/" do
    "I think you misunderstand how to use this."
  end

  post "/update_public" do
    public_repo = params[:public_repo]

    check_params params

    wipe_repos_dir
    clone_repo(public_repo)
    update_repo(public_repo)

    "Hey, you did it!"
  end

  post "/update_private" do
    private_repo = params[:private_repo]

    check_params params, true

    wipe_repos_dir
    clone_repo(private_repo)

    "Hey, you did it, privately!"

  end

  helpers do

    def check_params(params, is_private=false)
      return halt 500, "Tokens didn't match!" unless invalid_token?(params[:token])
      if is_private
        return halt 500, "Missing `private_repo` argument" if params[:private_repo].nil?
      else
        return halt 500, "Missing `public_repo` argument" if params[:public_repo].nil?
      end

      return halt 406, "Payload was not for master, aborting." unless master_branch?(@payload)
    end

    def invalid_token?(token)
      params[:token] == ENV["REPOSITORY_SYNC_TOKEN"]
    end

    def master_branch?(payload)
      payload["ref"] == "refs/heads/master"
    end

    def wipe_repos_dir
      system "rm -rf #{TEMP_REPO_PREFIX}"
    end

    def clone_repo(repo)
      FileUtils.mkdir_p "#{TEMP_REPO_PREFIX}/#{repo}"
      Dir.chdir "#{TEMP_REPO_PREFIX}/#{repo}" do
        IO.popen(["git", "init"])
        clone_command = IO.popen(["git", "pull", "https://github.com/#{repo}.git"])
        print_blocking_output(clone_command)
        IO.popen(["git", "remote", "add", "origin", "https://github.com/#{repo}.git"])
      end
    end

    def update_repo(repo)
      Dir.chdir "#{TEMP_REPO_PREFIX}/#{repo}" do
        remotename = "otherrepo-#{Time.now.to_i}"
        branchname = "update-#{Time.now.to_i}"
        remote_add = IO.popen(["git", "remote", "add", remotename, "https://github.com/#{@originating_repo}.git"])
        fetch_command = IO.popen(["git", "fetch", remotename])
        print_blocking_output(fetch_command)
        IO.popen(["git", "checkout", "-b", branchname])
        merge_command = IO.popen(["git", "merge", "--squash", "#{remotename}/master"])
        print_blocking_output(merge_command)
        merge_command = IO.popen(["git", "commit", "-m", '"Squashing and merging an update"'])
        push_command = IO.popen(["git", "push", "origin", branchname])
        print_blocking_output(push_command)
      end
    end

    def print_blocking_output(command)
      while (line = command.gets) # intentionally blocking call
        print line
      end
    end
  end
end
