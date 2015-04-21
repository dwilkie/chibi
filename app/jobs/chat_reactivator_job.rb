class ChatReactivatorJob < ActiveJob::Base
  queue_as Rails.application.secrets[:chat_reactivator_queue]

  def perform(chat_id)
    Chat.find(chat_id).reinvigorate!
  end
end
