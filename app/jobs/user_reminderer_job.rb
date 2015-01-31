class UserRemindererJob < ActiveJob::Base
  queue_as :low

  def perform(user_id, options = {})
    User.find(user_id).remind!(options)
  end
end
