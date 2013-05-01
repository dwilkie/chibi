class FriendFinder
  @queue = :friend_finder_queue

  def self.perform(options = {})
    User.find_friends(HashWithIndifferentAccess.new(options))
  rescue Resque::TermException
    Resque.enqueue(self, options)
  end
end
