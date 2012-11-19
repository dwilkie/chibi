class ChatDeactivator
  @queue = :chat_deactivator_queue

  def self.perform(chat_id, options = {})
    chat = Chat.find(chat_id)
    chat.deactivate!(HashWithIndifferentAccess.new(options))
  end
end
