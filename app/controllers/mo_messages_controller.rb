class MoMessagesController < ApplicationController
  http_basic_authenticate_with :name => Nuntium::CONFIG['incoming_user'], :password => Nuntium::CONFIG['incoming_password']

  def create
    MoMessage.create(params.slice :from, :body, :guid)
    render :nothing => true
  end
end

