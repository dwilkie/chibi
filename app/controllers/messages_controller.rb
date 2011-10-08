class MessagesController < ApplicationController
  def index
    @messages = Message.scoped
  end

  def create
    message = Message.new(params.slice :from, :body)
    message.user = User.find_or_create_by_mobile_number(message.origin)
    message.save
    message.process! # move this into a background process
    head :created, :location => messages_url(message)#, :links =>
  end

end

