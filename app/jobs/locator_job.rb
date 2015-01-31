class LocatorJob < ActiveJob::Base
  queue_as :high

  def perform(location_id, address)
    location = Location.find(location_id)
    location.locate!(address)
  end
end
