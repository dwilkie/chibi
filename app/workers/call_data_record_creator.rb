class CallDataRecordCreator
  @queue = :call_data_record_creator_queue

  def self.perform(body)
    CallDataRecord.new(:body => body).typed.save
  rescue Resque::TermException
    Resque.enqueue(self, body)
  end
end
