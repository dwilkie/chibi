class InvalidNamePurger < RetryWorker
  @queue = :invalid_name_purger_queue

  def self.perform(options = {})
    User.purge_invalid_names!
  end
end
