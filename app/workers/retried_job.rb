module RetriedJob
  def on_failure_retry(exception, *args)
    if exception.is_a?(Resque::TermException)
      Resque.enqueue(self, *args)
    end
  end
end
