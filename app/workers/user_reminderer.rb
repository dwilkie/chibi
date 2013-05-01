class UserReminderer
  @queue = :user_reminderer_queue

  def self.perform(user_id, options = {})
    User.find(user_id).remind!(HashWithIndifferentAccess.new(options))
  rescue Resque::TermException
    Resque.enqueue(self, user_id, options)
  end
end
