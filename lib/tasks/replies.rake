namespace :replies do
  desc "Removes old delivered replies"
  task :cleanup => :environment do
    Reply.cleanup!
  end
end
