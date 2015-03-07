class MessagesController < ApplicationController
  protect_from_forgery :except => :create

  before_action :authenticate_message

  def create
    status = (!accept_messages_from_nuntium? && Message.from_nuntium?(message_params)) ? :created : create_message
    render(:nothing => true, :status => status)
  end

  private

  def create_message
    message = Message.from_aggregator(message_params)

    if message.save
      message.queue_for_processing!
      :created
    else
      :bad_request
    end
  end

  def authenticate_message
    authenticate(:message)
  end

  def message_params
    params.permit!
  end

  def accept_messages_from_nuntium?
    nuntium_enabled? && nuntium_messages_enabled?
  end

  def nuntium_messages_enabled?
    Rails.application.secrets[:nuntium_messages_enabled] == "1"
  end

  def nuntium_enabled?
    Rails.application.secrets[:nuntium_enabled] == "1"
  end
end
