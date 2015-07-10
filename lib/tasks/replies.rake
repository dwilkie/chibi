namespace :replies do
  desc "Removes old delivered replies"
  task :cleanup => :environment do
    ReplyCleanupScheduledJob.perform_later
  end

  desc "Handles failed replies"
  task :handle_failed => :environment do
    ReplyHandleFailedScheduledJob.perform_later
  end

  desc "Fixes invalid states"
  task :fix_invalid_states => :environment do
    ReplyFixInvalidStatesScheduledJob.perform_later
  end
end
