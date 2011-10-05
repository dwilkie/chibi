class ApplicationController < ActionController::Base
  protect_from_forgery
  http_basic_authenticate_with :name => ENV["CHAT_BOX_USERNAME"], :password => ENV["CHAT_BOX_PASSWORD"]

  # force_ssl # this breaks the tests...

end

