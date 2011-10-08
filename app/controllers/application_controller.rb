class ApplicationController < ActionController::Base
  protect_from_forgery
  before_filter :authenticate
  #http_basic_authenticate_with :name => ENV["CHAT_BOX_USERNAME"], :password => ENV["CHAT_BOX_PASSWORD"]
  # force_ssl # this breaks the tests...

  protected

  def authenticate
    request_http_basic_authentication unless authenticate_with_http_basic {|username, password| username == ENV["CHAT_BOX_USERNAME"] && password == ENV["CHAT_BOX_PASSWORD"]}
  end
end

