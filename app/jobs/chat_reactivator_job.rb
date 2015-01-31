class ChatReactivatorJob < ActiveJob::Base
  queue_as :high

  def perform(chat_id)
    Chat.find(chat_id).reinvigorate!
  end
end
