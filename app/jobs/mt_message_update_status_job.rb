class MtMessageUpdateStatusJob
  include Sidekiq::Worker
  sidekiq_options :queue => Rails.application.secrets[:smpp_mt_message_update_status_queue]

  def perform(smsc_name, mt_message_id, smsc_message_id, status)
    Reply.find(mt_message_id).delivered_by_smsc!(smsc_name, smsc_message_id, status)
  end
end
