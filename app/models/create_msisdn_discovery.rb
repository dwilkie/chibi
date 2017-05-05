class MsisdnDiscovery < ApplicationRecord
  belongs_to :msisdn_discovery_run
  belongs_to :msisdn
end
