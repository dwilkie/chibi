class Reminderer
  @queue = :reminderer_queue

  def self.perform(options = {})
    User.remind!(HashWithIndifferentAccess.new(options))
  rescue Resque::TermException
    Resque.enqueue(self, options)
  end
end
