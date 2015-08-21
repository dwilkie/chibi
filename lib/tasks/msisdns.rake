namespace :msisdns do
  desc "Discovers MSISDNs for registered operators by broadcasting an SMS"
  task :discover => :environment do
    MsisdnDiscoveryRunScheduledJob.perform_later
  end

  desc "Cleans up MSISDN Discoveries"
  task :cleanup => :environment do
    MsisdnDiscoveryCleanupScheduledJob.perform_later
    MsisdnDiscoveryRunCleanupScheduledJob.perform_later
  end
end
