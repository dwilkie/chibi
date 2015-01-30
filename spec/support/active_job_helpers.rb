RSpec.configure do |config|
  config.before(:active_job => true) do
    clear_enqueued_jobs
  end
end

module ActiveJobHelpers
  include ActiveJob::TestHelper

  def trigger_job(options = {}, &block)
    if options[:queue_only]
      yield
    else
      perform_enqueued_jobs { yield }
    end
  end

  def first_enqueued_job
    @first_enqueued_job ||= enqueued_jobs.first
  end
end
