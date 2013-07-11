class MessagesController < ApplicationController
  protect_from_forgery :except => :create

  before_filter :authenticate_message

  def create
    message = Message.new(message_params.slice(:from, :body, :guid))
    if message.save
      message.queue_for_processing!
      status = :created
    else
      status = :bad_request
    end
    render(:nothing => true, :status => status)
  end

  private

  def authenticate_message
    authenticate(:message)
  end

  def message_params
    params.require(:message).permit(:body, :guid, :from)
  end
end
