class ApplicationController < ActionController::Base
  protect_from_forgery
  before_filter :authenticate

  # force_ssl # this breaks the tests...

  protected

  def authenticate
    authenticate_with_http_basic do |name, password|
      name == ENV["CHAT_BOX_USERNAME"] && password == ENV["CHAT_BOX_PASSWORD"]
    end
  end
end

