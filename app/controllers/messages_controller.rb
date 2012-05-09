class MessagesController < ApplicationController
  protect_from_forgery :except => :create

  before_filter :authenticate_message

  def create
    message = Message.new(params[:message].slice(:from, :body))
    if message.save
      Resque.enqueue(MessageProcessor, message.id)
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
end
