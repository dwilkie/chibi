job_class = Class.new(Object) do
  include Sidekiq::Worker
  sidekiq_options :queue => Rails.application.secrets[:smpp_mt_message_update_status_queue]

  def perform(smsc_name, mt_message_id, smsc_message_id, status)
    puts("SMSC NAME: #{smsc_name}, MT MESSAGE ID: #{mt_message_id}, SMSC MESSAGE ID: #{smsc_message_id}, STATUS: #{status}")
  end
end

Object.const_set(Rails.application.secrets[:smpp_mt_message_update_status_worker], job_class)
