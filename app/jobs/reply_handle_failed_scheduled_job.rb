class ReplyHandleFailedScheduledJob < ActiveJob::Base
  queue_as(Rails.application.secrets[:scheduled_queue])

  def perform
    Reply.handle_failed!
  end
end
