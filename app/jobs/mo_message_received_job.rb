job_class = Class.new(Object) do
  include Sidekiq::Worker
  sidekiq_options :queue => Rails.application.secrets[:smpp_mo_message_received_queue]

  def perform(smsc_name, source_address, dest_address, message_text)
    puts "------------------PROCESSING MO MESSAGE RECEIVED JOB--------------------"
    return unless worker_enabled?
    puts "------------------PROCESSING MO MESSAGE RECEIVED JOB (WORKER ENABLED!)--------------------"
    message = Message.from_smsc(
      :channel => smsc_name,
      :from => source_address,
      :to => dest_address,
      :body => message_text
    )
    message.save!
    puts "------------------PROCESSING MO MESSAGE RECEIVED JOB (MESSAGE SAVED!)--------------------"
    message.process!
    puts "------------------PROCESSING MO MESSAGE RECEIVED JOB (MESSAGE PROCESSED!)--------------------"
    puts "------------------PROCESSING MO MESSAGE RECEIVED JOB (MESSAGE #{message})--------------------"
  end

  private

  def worker_enabled?
    Rails.application.secrets[:smpp_mo_message_received_worker_enabled].to_i == 1
  end
end

Object.const_set(Rails.application.secrets[:smpp_mo_message_received_worker], job_class)
