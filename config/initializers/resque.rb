require 'resque/server'
#require 'resque-retry'
#require 'resque/failure/redis'
#require 'resque-retry/server'

Resque::Server.use(Rack::Auth::Basic) do |user, password|
  user == ENV["HTTP_BASIC_AUTH_ADMIN_USER"]
  password == ENV["HTTP_BASIC_AUTH_ADMIN_PASSWORD"]
end

#Resque::Failure::MultipleWithRetrySuppression.classes = [Resque::Failure::Redis]
#Resque::Failure.backend = Resque::Failure::MultipleWithRetrySuppression
