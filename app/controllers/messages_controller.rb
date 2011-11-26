class MessagesController < ApplicationController
  def index
    @messages = Message.scoped
  end

  def create
    message = Message.new(params.slice :from, :body)
    from = message.origin
    message.user = User.find_or_initialize_by_mobile_number(from)
    if message.save
      message.process! # move this into a background process
      response_params = {:status => :created, :location => messages_path(message)}
    else
      response_params = {:status => :bad_request}
    end
    render :nothing => true, response_params
  end
end
