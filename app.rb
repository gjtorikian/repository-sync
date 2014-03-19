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
    check_params params

    "Hey, you did it!"
  end

  post "/update_private" do
    check_params params

    "Hey, you did it, privately!"

  end

  helpers do

    def check_params(params)
      return halt 500, "Tokens didn't match!" if invalid_token?(params[:token]) && settings.environment != "development"

      payload = JSON.parse params[:payload]
      return halt 406, "Payload was not for master, aborting." unless master_branch?(payload)
    end

    def invalid_token?(token)
      params[:token] == ENV["token"]
    end

    def master_branch?(payload)
      payload["ref"] == "refs/heads/master"
    end

  end
end
