class UserReminderer
  extend RetriedJob
  @queue = :user_reminderer_queue

  def self.perform(user_id, options = {})
    User.find(user_id).remind!(HashWithIndifferentAccess.new(options))
  end
end
