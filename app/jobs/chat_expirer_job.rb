class ChatExpirerJob < ActiveJob::Base
  queue_as Rails.application.secrets[:chat_expirer_queue]

  def perform(options = {})
    Chat.end_inactive(options)
  end
end
