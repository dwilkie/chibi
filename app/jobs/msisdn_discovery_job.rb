class MsisdnDiscoveryJob < ActiveJob::Base
  queue_as Rails.application.secrets[:msisdn_discovery_queue]

  def perform(msisdn_discovery_run_id, subscriber_number)
    MsisdnDiscoveryRun.find(msisdn_discovery_run_id).discover!(subscriber_number)
  end
end
