class ChatExpirerScheduledJob < ActiveJob::Base
  queue_as(Rails.application.secrets[:scheduled_queue])

  def perform(mode)
    Chat.expire!(mode)
  end
end
