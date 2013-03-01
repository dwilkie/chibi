class UserReminderer < RetryWorker
  @queue = :user_reminderer_queue

  def self.perform(user_id, options = {})
    user = User.find(user_id)
    user.remind!(HashWithIndifferentAccess.new(options))
  end
end
