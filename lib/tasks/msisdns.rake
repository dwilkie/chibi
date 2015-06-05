namespace :msisdns do
  desc "Discovers MSISDNs for registered operators by broadcasting an SMS"
  task :discover => :environment do
    MsisdnDiscoveryRun.discover!
  end
end
