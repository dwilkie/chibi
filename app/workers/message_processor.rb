class MessageProcessor
  @queue = :message_processor_queue

  def self.perform(message_id)
    message = Message.find(message_id)
    message.process!
  rescue Resque::TermException
    Resque.enqueue(self, message_id)
  end
end
