if ENV["REDISTOGO_URL"] && Rails.env.production?
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  Resque.redis = REDIS
end
