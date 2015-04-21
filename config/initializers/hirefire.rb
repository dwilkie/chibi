HireFire::Resource.configure do |config|
  config.dyno(:worker) do
    HireFire::Macro::Sidekiq.queue(Rails.application.secrets[:internal_queues].to_s.split(":"))
  end
end
