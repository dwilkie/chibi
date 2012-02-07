require 'resque/server'

Resque::Server.use(Rack::Auth::Basic) do |user, password|
  user == ENV["HTTP_BASIC_AUTH_ADMIN_USER"]
  password == ENV["HTTP_BASIC_AUTH_ADMIN_PASSWORD"]
end
