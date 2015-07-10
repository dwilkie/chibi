class ReplyCleanupScheduledJob < ActiveJob::Base
  queue_as(Rails.application.secrets[:scheduled_queue])

  def perform
    Reply.cleanup!
  end
end
