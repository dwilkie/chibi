class MessageProcessorJob < ActiveJob::Base
  queue_as :message_processor_queue

  def perform(message_id)
    Message.find(message_id).process!
  end
end
