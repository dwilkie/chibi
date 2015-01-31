class RemindererJob < ActiveJob::Base
  queue_as :reminderer_queue

  def perform(options = {})
    User.remind!(options)
  end
end
