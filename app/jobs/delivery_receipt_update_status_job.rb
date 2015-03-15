job_class = Class.new(Object) do
  include Sidekiq::Worker
  sidekiq_options :queue => Rails.application.secrets[:smpp_delivery_receipt_update_status_queue]
  def perform(smsc_name, smsc_message_id, status)
    if reply = Reply.find_by_token(smsc_message_id)
      reply.delivery_status_updated_by_smsc!(smsc_name, status)
    end
  end
end

Object.const_set(Rails.application.secrets[:smpp_delivery_receipt_update_status_worker], job_class)
