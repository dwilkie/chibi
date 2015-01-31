class ChatExpirerJob < ActiveJob::Base
  queue_as :default

  def perform(options = {})
    Chat.end_inactive(options)
  end
end
