class MessageProcessorJob < ActiveJob::Base
  queue_as :urgent

  def perform(message_id)
    Message.find(message_id).process!
  end
end
