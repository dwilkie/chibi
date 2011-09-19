class ApplicationController < ActionController::Base
  protect_from_forgery
  before_filter :authenticate

  force_ssl

  protected

  def authenticate
    authenticate_with_http_basic do |username, password|
      account = Account.find_by_username(username)
      account && account.authenticate(password)
    end
  end
end

