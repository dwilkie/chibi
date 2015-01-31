class FriendMessengerJob < ActiveJob::Base
  queue_as :high

  def perform(user_id, options = {})
    User.find(user_id).find_friends!(options)
  end
end
