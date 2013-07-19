class UserImporter
  @queue = :user_importer_queue

  def self.perform(data)
    User.import!(data)
  rescue Resque::TermException
    Resque.enqueue(self, data)
  end
end
