class UserRemindererJob < ActiveJob::Base
  queue_as :user_reminderer_queue

  def perform(user_id, options = {})
    User.find(user_id).remind!(options)
  end
end
