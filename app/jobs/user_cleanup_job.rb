class UserCleanupJob < ActiveJob::Base
  queue_as Rails.application.secrets[:user_cleanup_queue]

  def perform(user_id)
    User.find(user_id).logout!
  end
end
