class ApplicationController < ActionController::Base
  protect_from_forgery

  protected

  # http_basic_authenticate_with cannot be overridden on a per controller basis
  def authenticate_admin
    authenticate(ENV["HTTP_BASIC_AUTH_ADMIN_USER"], ENV["HTTP_BASIC_AUTH_ADMIN_PASSWORD"])
  end

  def authenticate_api
    authenticate(ENV["HTTP_BASIC_AUTH_USER"], ENV["HTTP_BASIC_AUTH_PASSWORD"])
  end

  private

  def authenticate(username, password)
    request_http_basic_authentication unless authenticate_with_http_basic do |u, p|
      Rails.logger.log Logger::INFO, "incoming user: #{u}, incoming password: #{p}, username: #{username}, password: #{password}"
      u == username && p == password
    end
  end
end
