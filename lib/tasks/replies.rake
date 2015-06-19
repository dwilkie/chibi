namespace :replies do
  desc "Removes old delivered replies"
  task :cleanup => :environment do
    Reply.cleanup!
  end

  desc "Handles failed replies"
  task :handle_failed => :environment do
    Reply.handle_failed!
  end

  desc "Fixes invalid states"
  task :fix_invalid_states => :environment do
    Reply.fix_invalid_states!
  end
end
