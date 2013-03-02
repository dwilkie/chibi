module ResqueHelpers
  def do_background_task(options = {}, &block)
    queue_only = options.delete(:queue_only)
    if queue_only
      yield
    else
      with_resque { yield }
    end
  end

  def perform_background_job(queue_name)
    ResqueSpec.perform_all(queue_name)
  end
end
