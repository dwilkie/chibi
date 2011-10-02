class MessagesController < ApplicationController

  def index
    @messages = Message.scoped
  end

  def create
    message = Message.new(params.slice :from, :body)
    user = User.find_or_create_by_mobile_number(message.origin)
    message.subscription = @account.subscriptions.find_or_create_by_user_id(user.id)
    message.save
    message.process! # move this into a background process
    head :created, :location => messages_url(message)#, :links =>
  end

end

