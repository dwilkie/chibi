class FriendFinder < RetryWorker
  @queue = :friend_finder_queue

  def self.perform(options = {})
    User.find_friends(HashWithIndifferentAccess.new(options))
  end
end
