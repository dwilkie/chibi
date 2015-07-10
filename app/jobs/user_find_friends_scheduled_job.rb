class UserFindFriendsScheduledJob < ActiveJob::Base
  queue_as(Rails.application.secrets[:scheduled_queue])

  def perform
    User.find_friends!
  end
end
