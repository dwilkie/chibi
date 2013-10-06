class UserCreator
  extend RetriedJob
  @queue = :user_creator_queue

  def self.perform(mobile_number, metadata)
    User.create_unactivated!(mobile_number, metadata)
  end
end
