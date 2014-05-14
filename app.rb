require 'sinatra/base'
require 'json'
require 'fileutils'
require 'git'
require 'octokit'

class RepositorySync < Sinatra::Base
  set :root, File.dirname(__FILE__)

  # "Thin is a supremely better performing web server so do please use it!"
  set :server, %w[thin webrick]

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
        clone_repo(tmpdir)
        Dir.chdir "#{tmpdir}/#{@destination_repo}" do
          setup_git
          branchname, message = update_repo(is_public)
          return message if branchname.nil?
          puts "Working on branch #{branchname}"
          client = Octokit::Client.new(:access_token => token)
          new_pr = client.create_pull_request(@destination_repo, "master", branchname, "Sync changes from upstream repository", ":zap::zap::zap:")
          begin
            client.merge_pull_request(@destination_repo, new_pr[:number])
            puts "Merged PR ##{new_pr[:number]}"
            client.delete_branch(@destination_repo, branchname)
            puts "Deleted branch #{branchname}"
          rescue Octokit::ClientError => e
            return "Sorry, the CI is probably halting this auto-merge: #{e.message}"
          end
        end
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

    def clone_repo(tmpdir)
      puts "Cloning #{@destination_repo}..."
      @git_dir = Git.clone(clone_url_with_token(@destination_repo), "#{tmpdir}/#{@destination_repo}")
    end

    def setup_git
     @git_dir.config('user.name', 'Hubot')
     @git_dir.config('user.email', 'cwanstrath+hubot@gmail.com')
    end

    def update_repo(is_public)
      remotename = "otherrepo-#{Time.now.to_i}"
      branchname = "update-#{Time.now.to_i}"

      @git_dir.add_remote(remotename, clone_url_with_token(@originating_repo))
      puts "Fetching #{@originating_repo}..."
      @git_dir.remote(remotename).fetch
      @git_dir.branch(branchname).checkout

      begin
        # lol can't `merge --squash` with the git lib.
        puts "Merging #{@originating_repo}/master..."
        if is_public
          merge_command = IO.popen(["git", "merge", "--squash", "#{remotename}/master"])
          sleep 2
          @git_dir.commit('Sync changes from upstream repository')
        else
          merge_command = IO.popen(["git", "merge", "#{remotename}/master"])
          sleep 2
        end
      rescue Git::GitExecuteError => e
        if e.message =~ /nothing to commit/
          return nil, "#{e.message}"
        else
          halt 500, e.message
        end
      end

      print_blocking_output(merge_command)

      # not sure why push isn't working here
      puts "Pushing to origin..."
      merge_command = IO.popen(["git", "push", "origin", branchname])
      print_blocking_output(merge_command)
      branchname
    end

    def print_blocking_output(command)
      while (line = command.gets) # intentionally blocking call
        print line
      end
    end

    def clone_url_with_token(repo)
      "https://#{token}:x-oauth-basic@github.com/#{repo}.git"
    end
  end
end
