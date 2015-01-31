class ChatDeactivatorJob < ActiveJob::Base
  queue_as :chat_deactivator_queue

  def perform(chat_id, options = {})
    Chat.find(chat_id).deactivate!(options)
  end
end
