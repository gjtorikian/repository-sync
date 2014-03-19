require 'sinatra/base'

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
    if params[:token] == ENV["token"]
      payload = params[:payload]

      unless master_branch?(payload)
        Rails.logger.info "WEBHOOK: Payload was not for master, aborting."
        return
      end

      "Hey, you did it!"
    else
      "Tokens didn't match!"
    end
  end

  post "/update_private" do
    if params[:token] == ENV["token"]
      payload = params[:payload]

      unless master_branch?(payload)
        Rails.logger.info "WEBHOOK: Payload was not for master, aborting."
        return
      end

      "Hey, you did it, privately!"
    else
      "Tokens didn't match!"
    end
  end

  helpers do

    master_branch?(payload)
      payload["ref"] == "refs/heads/master"
    end

  end
end
