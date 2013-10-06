class Locator
  extend RetriedJob
  @queue = :locator_queue

  def self.perform(location_id, address)
    location = Location.find(location_id)
    location.locate!(address)
  end
end
