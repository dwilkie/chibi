class MessageCleanupJob < ActiveJob::Base
  queue_as Rails.application.secrets[:message_cleanup_queue]

  def perform(message_id)
    if message = Message.find_by_id(message_id)
      message.destroy_invalid_multipart!
    end
  end
end
