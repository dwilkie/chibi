class FriendMessenger
  @queue = :friend_messenger_queue

  def self.perform(user_id, options = {})
    user = User.find(user_id)
    user.find_friends!(HashWithIndifferentAccess.new(options))
  rescue Resque::TermException
    Resque.enqueue(self, user_id, options)
  end
end
