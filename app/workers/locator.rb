class Locator
  @queue = :locator_queue

  def self.perform(location_id, address)
    location = Location.find(location_id)
    location.locate!(address)
  rescue Resque::TermException
    Resque.enqueue(self, location_id, address)
  end
end
