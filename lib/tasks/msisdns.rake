namespace :msisdns do
  desc "Discovers MSISDNs for registered operators by broadcasting an SMS"
  task :discover => :environment do
    MsisdnDiscoveryRun.discover!
  end

  desc "Cleans up MSISDN Discoveries which have been queued too long"
  task :cleanup_queued => :environment do
    MsisdnDiscovery.cleanup_queued!
  end
end
