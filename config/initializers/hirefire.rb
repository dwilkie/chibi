HireFire::Resource.configure do |config|
  config.dyno(:worker) do
    HireFire::Macro::Resque.queue
  end

  config.dyno(:highloadworker) do
    HireFire::Macro::Resque.queue(
      :chat_reactivator_queue, :chat_deactivator_queue, :chat_expirer_queue
    )
  end
end
