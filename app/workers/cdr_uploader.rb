class CdrUploader
  extend RetriedJob
  @queue = :cdr_uploader_queue

  def self.perform(cdr_id)
    cdr = CallDataRecord.find(cdr_id)
    cdr_body = cdr.read_attribute(:body)
    cdr_body = cdr.body if cdr_body.is_a?(Hash)
    cdr.send(:set_cdr_data, cdr_body)
    cdr.save
  end
end
