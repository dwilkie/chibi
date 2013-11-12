namespace :charge_requests do
  desc "Timeout charge requests that are still awaiting a result after 24 hours"
  task :timeout => :environment do
    ChargeRequest.timeout!
  end
end
