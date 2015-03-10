# https://github.com/mhfs/sidekiq-failures#change-the-default-mode

Sidekiq.configure_server do |config|
  config.failures_default_mode = :exhausted
end
