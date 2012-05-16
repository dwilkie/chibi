namespace :chats do
  desc "Ends all active chats which have had no activity in the last 10 minutes. (These chats can be restarted)"
  task :end_inactive => :environment do
    Resque.enqueue(ChatExpirer, :active_user => true, :active => true)
  end

  desc "Terminates all chats which have had no activity in the last 24 hours. (These chats cannot be restarted)"
  task :terminate_inactive => :environment do
    Resque.enqueue(ChatExpirer, :inactivity_period => 24.hours)
  end
end
