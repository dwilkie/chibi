job_class = Class.new(Object) do
  include Sidekiq::Worker
  sidekiq_options :queue => Rails.application.secrets[:smpp_mo_message_received_queue]

  def perform(smsc_name, source_address, dest_address, message_text, csms_reference_num, csms_num_parts, csms_seq_num)
    message = Message.from_smsc(
      :channel => smsc_name,
      :from => source_address,
      :to => dest_address,
      :body => message_text,
      :csms_reference_number => csms_reference_num,
      :number_of_parts =>  csms_num_parts,
      :sequence_number => csms_seq_num
    )
    message.save!
    message.process!
  end
end

Object.const_set(Rails.application.secrets[:smpp_mo_message_received_worker], job_class)
