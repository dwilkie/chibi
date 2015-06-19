class MtMessageSenderJob < ActiveJob::Base
  queue_as Rails.application.secrets[:smpp_internal_mt_message_queue]

  def perform(reply_id, smpp_server_id, source_address, dest_address, message_body, smsc_priority = nil)
    MtMessageJobRunner.perform_async(
      smsc_priority.to_i.to_s,
      reply_id.to_s,
      smpp_server_id,
      source_address,
      dest_address,
      message_body
    )
  end
end
