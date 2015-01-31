class CallDataRecordCreatorJob < ActiveJob::Base
  queue_as :very_high

  def perform(body)
    cdr = CallDataRecord.new(:body => body)
    cdr.typed.save!
  end
end
