class MessageProcessorJob < ActiveJob::Base
  queue_as(Rails.application.secrets[:message_processor_queue])

  rescue_from(ActiveRecord::RecordNotFound) {}

  def perform(message_id)
    Message.find(message_id).pre_process!
  end
end
