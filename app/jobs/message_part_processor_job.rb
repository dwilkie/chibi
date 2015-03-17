class MessagePartProcessorJob < ActiveJob::Base
  queue_as Rails.application.secrets[:message_part_processor_queue]

  def perform(message_part_id)
    MessagePart.find(message_part_id).process!
  end
end
