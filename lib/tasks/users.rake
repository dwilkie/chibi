namespace :users do
  desc "Reminds users without recent interaction to use Chibi"
  task :remind => :environment do
    UserRemindScheduledJob.perform_later
  end

  desc "Finds new friends for users who are searching"
  task :find_friends => :environment do
    UserFindFriendsScheduledJob.perform_later
  end
end
