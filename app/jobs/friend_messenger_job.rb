class FriendMessengerJob < ActiveJob::Base
  queue_as Rails.application.secrets[:friend_messenger_queue]

  def perform(user_id, options = {})
    User.find(user_id).find_friends!(options)
  end
end
