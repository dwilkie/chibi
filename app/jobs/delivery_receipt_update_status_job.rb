class DeliveryReceiptUpdateStatusJob
  include Sidekiq::Worker
  sidekiq_options :queue => Rails.application.secrets[:smpp_delivery_receipt_update_status_queue]

  def perform(smsc_name, smsc_message_id, status)
    if reply = Reply.token_find!(smsc_message_id)
      reply.delivery_status_updated_by_smsc!(smsc_name, status)
    end
  end
end
