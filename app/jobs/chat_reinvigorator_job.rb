class ChatReinvigoratorJob < ActiveJob::Base
  queue_as Rails.application.secrets[:chat_reinvigorator_queue]

  def perform
    Chat.reinvigorate!
  end
end
