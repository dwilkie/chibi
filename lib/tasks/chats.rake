namespace :chats do
  desc "Ends all active chats which have had no activity in the last 10 minutes"
  task :end_inactive => :environment do
    Resque.enqueue(ChatExpirer)
  end
end
