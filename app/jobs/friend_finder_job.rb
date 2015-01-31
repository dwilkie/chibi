class FriendFinderJob < ActiveJob::Base
  queue_as :default

  def perform(options = {})
    User.find_friends(options)
  end
end
