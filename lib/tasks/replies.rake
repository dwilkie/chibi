namespace :replies do
  desc "Queries the state of any Reply that is 'queued_for_smsc_delivery' older than 10 minutes on Nuntium"
  task :query_queued => :environment do
    Reply.query_queued!
  end

  desc "Attempts to redeliver blank replies that were intended for forwarding"
  task :redeliver_blank => :environment do
    Reply.redeliver_blank!
  end
end
