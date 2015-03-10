class MtMessageJobRunner
  include Sidekiq::Worker
  sidekiq_options :queue => Rails.application.secrets[:smpp_external_mt_message_queue]
end
