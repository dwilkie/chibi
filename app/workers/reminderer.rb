class Reminderer < RetryWorker
  @queue = :reminderer_queue

  def self.perform(options = {})
    User.remind!(HashWithIndifferentAccess.new(options))
  end
end
