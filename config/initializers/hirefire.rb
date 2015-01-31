HireFire::Resource.configure do |config|
  config.dyno(:critical_task_worker) do
    HireFire::Macro::Sidekiq.queue(
      :critical,
      :urgent
    )
  end

  config.dyno(:non_critical_task_worker) do
    HireFire::Macro::Sidekiq.queue(
      :very_high,
      :high,
      :default,
      :low,
      :very_low
    )
  end
end
