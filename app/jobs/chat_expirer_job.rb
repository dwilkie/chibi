class ChatExpirerJob < ActiveJob::Base
  queue_as(Rails.application.secrets[:chat_expirer_queue])

  def perform(chat_id, mode)
    Chat.find(chat_id).expire!(mode)
  end
end
