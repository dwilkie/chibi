class MessagesController < ApplicationController
  protect_from_forgery :except => :create

  before_action :authenticate_message

  def create
    message = Message.from_aggregator(message_params)

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
    params.permit!
  end
end
