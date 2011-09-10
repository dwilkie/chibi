class MoMessagesController < ApplicationController
  http_basic_authenticate_with :name => "sms", :password => "dating"

  def create
    MoMessage.create(params)
  end
end

