class ChatReinvigoratorScheduledJob < ActiveJob::Base
  queue_as(Rails.application.secrets[:scheduled_queue])

  def perform
    Chat.reinvigorate!
  end
end
