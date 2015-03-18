class UserRemindererJob < ActiveJob::Base
  queue_as Rails.application.secrets[:user_reminderer_job_queue]

  def perform(user_id, options = {})
    User.find(user_id).remind!(options)
  end
end
