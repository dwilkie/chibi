class ChatReinvigorator
  @queue = :chat_reinvigorator_queue

  def self.perform
    Chat.reinvigorate!
  rescue Resque::TermException
    Resque.enqueue(self)
  end
end
