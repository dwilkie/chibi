class UserReminderer < RetryWorker
  @queue = :user_reminderer_queue

  def self.perform(user_id)
    user = User.find(user_id)
    user.remind!
  end
end
