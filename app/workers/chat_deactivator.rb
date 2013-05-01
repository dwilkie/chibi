class ChatDeactivator
  @queue = :chat_deactivator_queue

  def self.perform(chat_id, options = {})
    chat = Chat.find(chat_id)
    chat.deactivate!(HashWithIndifferentAccess.new(options))
  rescue Resque::TermException
    Resque.enqueue(self, chat_id, options)
  end
end
