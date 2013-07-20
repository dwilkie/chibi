namespace :users do
  desc "Reminds users without recent interaction to use Chibi"
  task :remind => :environment do
    Resque.enqueue(Reminderer, :limit => 300, :inactivity_period => 3.days, :between => 0..17)
  end

  desc "Finds new friends for users who are searching"
  task :find_friends => :environment do
    Resque.enqueue(FriendFinder, :notify => true, :notify_no_match => false, :between => 0..17)
  end

  desc "Sets User#activated_at to User#created_at for already activated users"
  task :set_activated_at => :environment do
    User.set_activated_at
  end
end
