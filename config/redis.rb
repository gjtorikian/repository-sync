require 'resque'

def configure_redis
  Resque.redis = if ENV['RACK_ENV'] == 'production'
    uri = URI.parse(ENV['REDISTOGO_URL'])
     Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  else
    Redis.new
  end
end
