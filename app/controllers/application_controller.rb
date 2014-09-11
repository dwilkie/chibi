class ApplicationController < ActionController::Base
  protect_from_forgery

  private

  # http_basic_authenticate_with cannot be overridden on a per controller basis
  def authenticate_admin
    authenticate(:admin)
  end

  def authenticate(resource)
    authentication_key = "HTTP_BASIC_AUTH_#{resource.upcase}"
    http_basic_authenticate(ENV["#{authentication_key}_USER"], ENV["#{authentication_key}_PASSWORD"])
  end

  def http_basic_authenticate(username, password)
    request_http_basic_authentication unless authenticate_with_http_basic {|u, p| u == username && p == password}
  end
end
