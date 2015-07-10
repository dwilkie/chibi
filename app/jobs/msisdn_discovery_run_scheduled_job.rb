class MsisdnDiscoveryRunScheduledJob < ActiveJob::Base
  queue_as(Rails.application.secrets[:scheduled_queue])

  def perform
    MsisdnDiscoveryRun.discover!
  end
end
