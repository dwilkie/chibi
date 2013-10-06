class CallDataRecordCreator
  extend RetriedJob
  @queue = :call_data_record_creator_queue

  def self.perform(body)
    cdr = CallDataRecord.new(:body => body)
    cdr.typed.save!
  end
end
