HireFire::Resource.configure do |config|
  config.dyno(:urgent_task_worker) do
    HireFire::Macro::Resque.queue(
      :call_data_record_creator_queue,
      :charge_request_updater_queue,
      :message_processor_queue,
      :twilio_cdr_fetcher_queue,
      :delivery_receipt_creator_queue,
      :dialer_queue
    )
  end

  config.dyno(:non_essential_task_worker_1) do
    HireFire::Macro::Resque.queue(
      :user_creator_queue,
      :user_importer_queue
    )
  end

  config.dyno(:non_essential_task_worker_2) do
    HireFire::Macro::Resque.queue(
      :chat_deactivator_queue,
      :chat_expirer_queue
    )
  end

  config.dyno(:non_essential_task_worker_3) do
    HireFire::Macro::Resque.queue(
      :friend_messenger_queue,
      :friend_finder_queue
    )
  end

  config.dyno(:non_essential_task_worker_4) do
    HireFire::Macro::Resque.queue(
      :user_reminderer_queue,
      :reminderer_queue
    )
  end

  config.dyno(:non_essential_task_worker_5) do
    HireFire::Macro::Resque.queue(
      :chat_reactivator_queue,
      :chat_reinvigorator_queue
    )
  end

  config.dyno(:non_essential_task_worker_6) do
    HireFire::Macro::Resque.queue(
      :locator_queue
    )
  end

  config.dyno(:non_essential_task_worker_7) do
    HireFire::Macro::Resque.queue(
      :report_generator_queue
    )
  end
end
