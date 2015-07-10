namespace :messages do
  desc "Queues unprocessed multipart messages for processing"
  task :queue_unprocessed => :environment do
    MultipartMessageProcessorScheduledJob.perform_later
  end
end
