class ChatReactivator
  extend RetriedJob
  @queue = :chat_reactivator_queue

  def self.perform(chat_id)
    Chat.find(chat_id).reinvigorate!
  end
end
