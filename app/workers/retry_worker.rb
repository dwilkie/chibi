class RetryWorker
  extend Resque::Plugins::Retry

  def self.retry_exceptions
    [Redis::CommandError, Resque::TermException]
  end

  def self.retry_delay
    0 # seconds
  end

  def self.retry_limit
    5 # times
  end
end
