job_class = Class.new(Object) do
  include Sidekiq::Worker
  sidekiq_options :queue => Rails.application.secrets[:smpp_mo_message_received_queue]

  def perform(smsc_name, source_address, dest_address, message_text)
    puts("SMSC NAME: #{smsc_name}, SOURCE ADDRESS: #{source_address}, DEST ADDRESS: #{dest_address}, MESSAGE TEXT: #{message_text}")
  end
end

Object.const_set(Rails.application.secrets[:smpp_mo_message_received_worker], job_class)
