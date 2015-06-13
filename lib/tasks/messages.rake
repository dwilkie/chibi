namespace :messages do
  desc "Queues unprocessed multipart messages for processing"
  task :queue_unprocessed => :environment do
    Message.queue_unprocessed_multipart!
  end
end
