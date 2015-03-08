class MessagesController < ApplicationController
  protect_from_forgery :except => :create

  before_action :authenticate_message

  def create
    status = (from_nuntium? && !accept_messages_from_channel?) ? :created : create_message
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

  def from_nuntium?
    Message.from_nuntium?(message_params)
  end

  def accept_messages_from_channel?
    accept_messages_from_nuntium? && Message.accept_messages_from_channel?(message_params)
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
