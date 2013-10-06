class FriendMessenger
  extend RetriedJob
  @queue = :friend_messenger_queue

  def self.perform(user_id, options = {})
    user = User.find(user_id)
    user.find_friends!(HashWithIndifferentAccess.new(options))
  end
end
