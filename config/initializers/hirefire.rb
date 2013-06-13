HireFire::Resource.configure do |config|
  config.dyno(:urgent_task_worker) do
    HireFire::Macro::Resque.queue(
      :message_processor_queue,
      :dialer_queue,
      :call_data_record_creator_queue,
      :twilio_cdr_fetcher_queue
    )
  end

  config.dyno(:non_essential_task_worker) do
    HireFire::Macro::Resque.queue(
      :locator_queue,
      :chat_reactivator_queue,
      :chat_deactivator_queue,
      :chat_expirer_queue,
      :friend_messenger_queue,
      :friend_finder_queue,
      :user_reminderer_queue,
      :reminderer_queue,
      :nuntium_ao_queryer_queue,
      :blank_reply_fixer_queue
    )
  end
end
