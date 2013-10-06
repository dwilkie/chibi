class UserImporter
  extend RetriedJob
  @queue = :user_importer_queue

  def self.perform(data)
    User.import!(data)
  end
end
