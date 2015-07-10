namespace :charge_requests do
  desc "Timeout charge requests that are awaiting a result for too long"
  task :timeout => :environment do
    ChargeRequestTimeoutScheduledJob.perform_later
  end
end
