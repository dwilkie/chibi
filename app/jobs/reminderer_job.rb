class RemindererJob < ActiveJob::Base
  queue_as Rails.application.secrets[:reminderer_queue]

  def perform(options = {})
    User.remind!(options)
  end
end
