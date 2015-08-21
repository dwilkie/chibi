class MsisdnDiscoveryRunCleanupScheduledJob < ActiveJob::Base
  queue_as(Rails.application.secrets[:scheduled_queue])

  def perform
    MsisdnDiscoveryRun.cleanup!
  end
end
