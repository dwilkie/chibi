class MsisdnDiscoveryJob < ActiveJob::Base
  queue_as Rails.application.secrets[:msisdn_discovery_queue]

  def perform(mobile_number)
    Msisdn.where(:mobile_number => mobile_number).first_or_create!.discover!
  end
end
