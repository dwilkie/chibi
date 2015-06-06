Airbrake.configure do |config|
  config.api_key = ENV["AIRBRAKE_API_KEY"]
  config.host    = ENV["AIRBRAKE_HOST"]
  config.port    = 443
  config.secure  = config.port == 443

  # this will be retried succesfully
  config.ignore_by_filter do |exception_data|
    exception_data["error_class"] == "AASM::InvalidTransition" &&
    (exception_data["parameters"] || {})["class"] == "DeliveryReceiptUpdateStatusJob"
  end

  # this will be retried succesfully
  config.ignore_by_filter do |exception_data|
    exception_data["error_class"] == "PG::TRDeadlockDetected" &&
    (exception_data["parameters"] || {})["class"] == "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"
  end
end
