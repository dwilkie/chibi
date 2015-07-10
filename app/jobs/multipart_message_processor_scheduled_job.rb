class MultipartMessageProcessorScheduledJob < ActiveJob::Base
  queue_as(Rails.application.secrets[:scheduled_queue])

  def perform
    Message.queue_unprocessed_multipart!
  end
end
