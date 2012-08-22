namespace :users do
  desc "Reminds users without recent interaction to use Chibi"
  task :remind => :environment do
    Resque.enqueue(UserReminder, :limit => 500)
  end

  desc "Finds new friends for users who are searching"
  task :find_friends => :environment do
    Resque.enqueue(FriendFinder, :notify => true, :notify_no_match => false, :between => 1..15)
  end
end
