namespace :chats do
  desc "Provisionally deactivates chats with inactivity"
  task :provisionally_deactivate => :environment do
    ChatExpirerScheduledJob.perform_later("provisional")
  end

  desc "Permanently deactivates chats with inactivity"
  task :permanently_deactivate => :environment do
    ChatExpirerScheduledJob.perform_later("permanent")
  end

  desc "Reactivates chats which have pending messages"
  task :reinvigorate => :environment do
    ChatReinvigoratorScheduledJob.perform_later
  end

  desc "Removes old chats that have no interaction"
  task :cleanup => :environment do
    ChatCleanupScheduledJob.perform_later
  end
end
