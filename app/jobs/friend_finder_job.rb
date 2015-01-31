class FriendFinderJob < ActiveJob::Base
  queue_as :friend_finder_queue

  def perform(options = {})
    User.find_friends(options)
  end
end
