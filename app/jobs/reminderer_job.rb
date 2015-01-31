class RemindererJob < ActiveJob::Base
  queue_as :very_low

  def perform(options = {})
    User.remind!(options)
  end
end
