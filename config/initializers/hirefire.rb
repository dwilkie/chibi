HireFire::Resource.configure do |config|
  config.dyno(:worker) do
    HireFire::Macro::Resque.queue(:message_processor_queue, :dialer_queue)
  end

  config.dyno(:highloadworker) do
    HireFire::Macro::Resque.queue(
      :chat_reactivator_queue,
      :chat_deactivator_queue,
      :chat_expirer_queue,
      :friend_messenger_queue,
      :friend_finder_queue,
      :user_reminderer_queue,
      :reminderer_queue
    )
  end
end
