class MsisdnDiscoveryCleanupScheduledJob < ActiveJob::Base
  queue_as(Rails.application.secrets[:scheduled_queue])

  def perform
    MsisdnDiscovery.cleanup!
  end
end
