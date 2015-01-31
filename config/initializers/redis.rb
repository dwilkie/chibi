redis_url_options = {}

if Rails.env.production? && ENV["REDISTOGO_URL"]
  uri = URI.parse(ENV["REDISTOGO_URL"])
  redis_url_options.merge!(:host => uri.host, :port => uri.port, :password => uri.password)
end

unless Rails.env.test?
  REDIS = Redis.new(redis_url_options)
end
