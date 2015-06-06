class FriendMessengerJob < ActiveJob::Base
  queue_as Rails.application.secrets[:friend_messenger_queue]

  def perform(user_id)
    User.find(user_id).find_friends!
  end
end
