namespace :users do
  desc "Reminds users without recent interaction to use Chibi"
  task :remind => :environment do
    RemindererJob.perform_later(:limit => 300, :inactivity_cutoff => 24.hours.ago.to_s, :between => [6, 24])
  end

  desc "Finds new friends for users who are searching"
  task :find_friends => :environment do
    FriendFinderJob.perform_later(:notify => true, :notify_no_match => false, :between => [6, 24])
  end
end
