class ReplyFixInvalidStatesScheduledJob < ActiveJob::Base
  queue_as(Rails.application.secrets[:scheduled_queue])

  def perform
    Reply.fix_invalid_states!
  end
end
