class ChatReinvigorator
  @queue = :chat_reinvigorator_queue

  def self.perform
    Chat.reinvigorate!
  end
end
