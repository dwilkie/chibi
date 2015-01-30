class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  private

  # http_basic_authenticate_with cannot be overridden on a per controller basis
  def authenticate_admin
    authenticate(:admin)
  end

  def authenticate(resource)
    authentication_key = "http_basic_auth_#{resource}"
    http_basic_authenticate(
      Rails.application.secrets[:"#{authentication_key}_user"],
      Rails.application.secrets[:"#{authentication_key}_password"]
    )
  end

  def http_basic_authenticate(username, password)
    request_http_basic_authentication unless authenticate_with_http_basic {|u, p| u == username && p == password}
  end
end
