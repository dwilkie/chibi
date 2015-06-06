class UserRemindererJob < ActiveJob::Base
  queue_as Rails.application.secrets[:user_reminderer_queue]

  def perform(user_id)
    User.find(user_id).remind!
  end
end
