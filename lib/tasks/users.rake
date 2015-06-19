namespace :users do
  desc "Reminds users without recent interaction to use Chibi"
  task :remind => :environment do
    User.remind!
  end

  desc "Finds new friends for users who are searching"
  task :find_friends => :environment do
    User.find_friends!
  end
end
