require 'sinatra/base'
require 'json'

class RepositorySync < Sinatra::Base
  set :root, File.dirname(__FILE__)

  # "Thin is a supremely better performing web server so do please use it!"
  set :server, %w[thin webrick]

  # trim trailing slashes
  before do
    request.path_info.sub! %r{/$}, ''
  end

  get "/" do
    "I think you misunderstand how to use this."
  end

  post "/update_public" do
    payload = JSON.parse params[:payload]
    public_repo = params[:public_repo]

    check_params params, payload

    clone_repo(public_repo)

    "Hey, you did it!"
  end

  post "/update_private" do
    payload = JSON.parse params[:payload]
    private_repo = params[:private_repo]

    check_params params, payload, true

    clone_repo(private_repo)

    "Hey, you did it, privately!"

  end

  helpers do

    def check_params(params, payload, is_private)
      return halt 500, "Tokens didn't match!" if invalid_token?(params[:token]) && settings.environment != "development"
      if is_private
        return halt 500, "Missing `private_repo` argument" if params[:private_repo].nil?
      else
        return halt 500, "Missing `public_repo` argument" if params[:public_repo].nil?
      end

      return halt 406, "Payload was not for master, aborting." unless master_branch?(payload)
    end

    def invalid_token?(token)
      params[:token] == ENV["token"]
    end

    def master_branch?(payload)
      payload["ref"] == "refs/heads/master"
    end

    def clone_repo(repo)
      IO.popen(["git", "clone", "https://www.github.com/#{repo}"])
    end
  end
end
