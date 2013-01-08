class UserReminder < RetryWorker
  @queue = :user_reminder_queue

  def self.perform(user_id)
    user = User.find(user_id)
    user.remind!
  end
end
