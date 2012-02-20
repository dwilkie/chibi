class ChatDeactivator
  @queue = :chat_deactivator_queue

  def self.perform(chat_id, options = {})
    p "***********************"
    p "start chat deactivator"
    p ""
    p "chat id:"
    p chat_id
    chat = Chat.find(chat_id)
    p "chat"
    p chat
    p "chat.active?"
    p chat.active?
    p "options"
    p options
    chat.deactivate!(options)
    p "end chat deactivator"
    p "**********************"
  end
end
