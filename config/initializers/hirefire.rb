HireFire::Resource.configure do |config|
  config.dyno(:worker) do
    HireFire::Macro::Sidekiq.queue(
      :critical,
      :urgent,
      :very_high,
      :high,
      :default,
      :low,
      :very_low
    )
  end
end
