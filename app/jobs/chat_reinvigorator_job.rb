class ChatReinvigoratorJob < ActiveJob::Base
  queue_as(Rails.application.secrets[:chat_reinvigorator_queue])

  def perform(chat_id)
    Chat.find(chat_id).reinvigorate!
  end
end
