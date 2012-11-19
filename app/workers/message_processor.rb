class MessageProcessor
  @queue = :message_processor_queue

  def self.perform(message_id)
    p "try touching the worker..."
    message = Message.find(message_id)
    message.process!
  end
end
