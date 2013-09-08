class ChatReinvigorator
  @queue = :chat_reinvigorator_queue

  def self.perform
    Chat.reactivate_stagnant!
  rescue Resque::TermException
    Resque.enqueue(self)
  end
end
