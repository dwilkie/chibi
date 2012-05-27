class UserReminder
  @queue = :user_reminder_queue

  def self.perform(options = {})
    User.remind!(HashWithIndifferentAccess.new(options))
  end
end
