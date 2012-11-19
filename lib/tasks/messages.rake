namespace :messages do
  desc "Queues for processing any messages which have not yet been queued"
  task :queue_unprocessed => :environment do
    Message.queue_unprocessed(3.minutes.ago)
  end
end
