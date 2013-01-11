namespace :users do
  desc "Reminds users without recent interaction to use Chibi"
  task :remind => :environment do
    Resque.enqueue(Reminderer, :limit => 1000, :inactivity_period => 3.days, :between => 2..15)
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
