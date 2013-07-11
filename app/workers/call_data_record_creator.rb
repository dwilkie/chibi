class CallDataRecordCreator
  @queue = :call_data_record_creator_queue

  def self.perform(body)
    cdr = CallDataRecord.new(:body => body)
    cdr.typed.save!
  rescue Resque::TermException
    Resque.enqueue(self, body)
  end
end
