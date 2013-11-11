module ResqueHelpers
  EXTERNAL_QUEUES = [ENV["CHIBI_BILLER_CHARGE_REQUEST_QUEUE"]]

  def do_background_task(options = {}, &block)
    ResqueSpec.reset!

    yield

    unless options.delete(:queue_only)
      # don't perform jobs that are not intended to be performed by this app
      queues = ResqueSpec.queues.reject { |k, v| k =~ /mt_message_queue$/ || EXTERNAL_QUEUES.include?(k.to_s) }
      queues.keys.each do |queue_name|
        ResqueSpec.perform_all(queue_name)
      end
    end
  end

  def perform_background_job(queue_name)
    ResqueSpec.perform_all(queue_name)
  end
end
