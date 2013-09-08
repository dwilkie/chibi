class ChatReactivator
  @queue = :chat_reactivator_queue

  def self.perform(chat_id)
    Chat.find(chat_id).reactivate!
  rescue Resque::TermException
    Resque.enqueue(self, chat_id)
  end
end
