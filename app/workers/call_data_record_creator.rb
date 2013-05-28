class CallDataRecordCreator
  @queue = :call_data_record_creator_queue

  def self.perform(body)
    CallDataRecord.create!(:body => body)
  rescue Resque::TermException
    Resque.enqueue(self, body)
  end
end
