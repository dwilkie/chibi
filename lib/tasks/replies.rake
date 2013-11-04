namespace :replies do
  desc "Queries the Nuntium AO of any reply that is 'queued_for_smsc_delivery' older than 10 minutes"
  task :query_queued => :environment do
    Reply.query_queued!
  end

  desc "Attempts to fix blank replies and marks them as undelivered"
  task :fix_blank => :environment do
    Reply.fix_blank!
  end

  desc "Removes old delivered replies"
  task :cleanup => :environment do
    Reply.cleanup!
  end
end
