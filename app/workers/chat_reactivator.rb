class ChatReactivator < RetryWorker
  @queue = :chat_reactivator_queue

  def self.perform(chat_id = nil)
    chat_id.present? ? Chat.find(chat_id).reactivate! : Chat.reactivate_stagnant!
  end
end
