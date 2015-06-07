class MtMessageUpdateStatusJob
  include Sidekiq::Worker
  sidekiq_options(:queue => Rails.application.secrets[:smpp_mt_message_update_status_queue])

  def perform(smsc_name, mt_message_id, smsc_message_id, successful, error_message = nil)
    Reply.find(mt_message_id).delivered_by_smsc!(smsc_name, smsc_message_id, successful, error_message)
  end
end
