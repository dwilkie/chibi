class CdrUploader
  extend RetriedJob
  @queue = :cdr_uploader_queue

  def self.perform(cdr_id)
    cdr = CallDataRecord.find(cdr_id)
    cdr.send(:set_cdr_data, cdr.read_attribute(:body))
    cdr.save!
  end
end
