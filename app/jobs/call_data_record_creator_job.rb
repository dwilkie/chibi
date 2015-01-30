class CallDataRecordCreatorJob < ActiveJob::Base
  queue_as :call_data_record_creator_queue

  def perform(body)
    cdr = CallDataRecord.new(:body => body)
    cdr.typed.save!
  end
end
