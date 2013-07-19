class UserCreator
  @queue = :user_creator_queue

  def self.perform(mobile_number, metadata)
    User.create_unactivated!(mobile_number, metadata)
  rescue Resque::TermException
    Resque.enqueue(self, mobile_number, metadata)
  end
end
