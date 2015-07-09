class ChatCleanupScheduledJob < ActiveJob::Base
  queue_as(Rails.application.secrets[:scheduled_queue])

  def perform
    Chat.cleanup!
  end
end
