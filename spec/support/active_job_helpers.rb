module ActiveJobHelpers
  include ActiveJob::TestHelper

  def trigger_job(options = {}, &block)
    if options.delete(:queue_only)
      yield
    else
      perform_enqueued_jobs { yield }
    end
  end
end
