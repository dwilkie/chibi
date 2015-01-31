class ChatDeactivatorJob < ActiveJob::Base
  queue_as :high

  def perform(chat_id, options = {})
    Chat.find(chat_id).deactivate!(options)
  end
end
