class ChatReinvigoratorJob < ActiveJob::Base
  queue_as :default

  def perform
    Chat.reinvigorate!
  end
end
