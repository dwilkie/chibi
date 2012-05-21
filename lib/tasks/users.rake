namespace :users do
  desc "Reminds users without recent interaction to use Chibi"
  task :remind => :environment do
    User.remind!
  end
end
