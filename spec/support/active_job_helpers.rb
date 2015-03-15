module ActiveJobHelpers
  include ActiveJob::TestHelper

  def trigger_job(options = {}, &block)
    if options.delete(:queue_only)
      yield
    else
      stub_unwanted_jobs(options[:only])
      perform_enqueued_jobs { yield }
    end
  end

  # This can be removed in Rails 5

  def stub_unwanted_jobs(only = nil)
    if only
      (active_jobs - only).each do |job|
        allow(job).to receive(:set).and_return(job)
        allow(job).to receive(:perform_later).and_return(nil)
      end
    end
  end

  def active_jobs
    Rails.application.eager_load!
    ActiveJob::Base.descendants
  end
end
