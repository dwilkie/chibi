namespace :chats do
  desc "Ends all active chats which have had no activity in the last 10 minutes. (These chats can be restarted)"
  task :end_inactive => :environment do
    ChatExpirerJob.perform_later(:active_user => true, :activate_new_chats => true)
  end

  desc "Terminates all chats which have had no activity in the last 24 hours. (These chats cannot be restarted)"
  task :terminate_inactive => :environment do
    ChatExpirerJob.perform_later(:all => true, :inactivity_period => 24.hours.ago)
  end

  desc "Reactivates stagnant chats which have pending messages"
  task :reactivate_stagnant => :environment do
    ChatReinvigoratorJob.perform_later
  end

  desc "Removes old chats that have no interaction"
  task :cleanup => :environment do
    Chat.cleanup!
  end
end
