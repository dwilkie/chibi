namespace :users do
  desc "Finds new friends for users without recent interaction"
  task :remind => :environment do
    Resque.enqueue(UserReminder, :limit => 100, :notify => true, :notify_no_match => false)
  end

  desc "Finds new friends for users who are searching"
  task :find_friends => :environment do
    Resque.enqueue(FriendFinder, :notify => true, :notify_no_match => false, :between => 1..16)
  end

  desc "Purge invalid names"
  task :purge_invalid_names => :environment do
    Resque.enqueue(InvalidNamePurger)
  end
end
