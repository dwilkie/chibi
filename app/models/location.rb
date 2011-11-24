class Location < ActiveRecord::Base
  belongs_to :user

  attr_accessor :address

  geocoded_by :full_address

  reverse_geocoded_by :latitude, :longitude do |location, results|
    if (result = results.first) && (result.country_code == location.country_code)
      location.city = result.city
    else
      location.latitude = nil
      location.longitude = nil
    end
  end

  validates :country_code, :presence => true

  def self.country_code(mobile_number)
    DIALING_CODES[Phony.split(mobile_number).first]
  end

  # move into a background job
  def locate!
    geocode
    reverse_geocode if latitude? && longitude?
  end

  private

  def country
    ISO3166::Country[country_code].name
  end

  def full_address
    address + ", #{country}" if address.present? && country_code?
  end
end

