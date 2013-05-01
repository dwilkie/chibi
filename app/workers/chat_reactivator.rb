class ChatReactivator
  @queue = :chat_reactivator_queue

  def self.perform(chat_id = nil)
    chat_id.present? ? Chat.find(chat_id).reactivate! : Chat.reactivate_stagnant!
  rescue Resque::TermException
    Resque.enqueue(self, chat_id)
  end
end
