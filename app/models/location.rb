class Location < ActiveRecord::Base
  belongs_to :user

  attr_accessor :address, :mobile_number

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

  before_validation :locate

  def self.country_code(mobile_number)
    DIALING_CODES[Phony.split(mobile_number).first]
  end

  private

  def locate
    find_country_code_from_mobile_number
    find_city_from_address if address_changed? && country_code?
  end

  def address_changed?
    address.present?
  end

  def country
    ISO3166::Country[country_code].name
  end

  def full_address
    address.present? ? address + ", #{country}" : address
  end

  def find_country_code_from_mobile_number
    self.country_code = self.class.country_code(mobile_number) if mobile_number.present?
  end

  # move into a background job
  def find_city_from_address
    geocode
    reverse_geocode if latitude? && longitude?
  end
end

