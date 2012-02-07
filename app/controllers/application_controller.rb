class ApplicationController < ActionController::Base
  protect_from_forgery
  http_basic_authenticate_with :name => ENV["HTTP_BASIC_AUTH_USER"], :password => ENV["HTTP_BASIC_AUTH_PASSWORD"]
end
