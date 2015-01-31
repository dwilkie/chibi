class ChatReinvigoratorJob < ActiveJob::Base
  queue_as :chat_reinvigorator_queue

  def perform
    Chat.reinvigorate!
  end
end
