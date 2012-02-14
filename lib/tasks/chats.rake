namespace :chats do
  desc "Ends all active chats which have had no activity in the last 10 minutes"
  task :end_inactive => :environment do
    Chat.end_inactive(:notify => true)
  end
end
