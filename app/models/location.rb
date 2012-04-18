# encoding: utf-8

class Location < ActiveRecord::Base
  belongs_to :user
  before_save :normalize_country_code

  attr_accessor :address

  geocoded_by :full_address

  reverse_geocoded_by :latitude, :longitude do |location, results|
    if (result = results.first) && (result.country_code.downcase == location.country_code)
      location.city = result.city
    else
      location.latitude = nil
      location.longitude = nil
    end
  end

  validates :country_code, :presence => true

  # long running task
  def locate!
    if address.present? && country_code?
      localize_address!
      geocode
      reverse_geocode if latitude? && longitude? && (latitude_changed? || longitude_changed?)
    end
  end

  def country_code
    raw_country_code = read_attribute(:country_code)
    raw_country_code.to_s.downcase if raw_country_code
  end

  private

  def normalize_country_code
    self.country_code = country_code.downcase
  end

  def country
    ISO3166::Country[country_code.upcase]
  end

  def full_address
    address + ", #{country.name}"
  end

  def localize_address!
    address_words.each do |address_word|
      if local_address = subdivision_names[address_word]
        self.address = local_address
        break
      end
    end
  end

  def address_words
    address.downcase.split(/[^\p{Word}|\.]/)
  end

  def subdivision_names
    unless @subdivision_names
      @subdivision_names = {}

      country.subdivisions.values.each do |subdivision|
        subdivision_name = subdivision["name"].gsub(/\[.+\]/, "").strip.downcase
        other_names = [subdivision["names"]].flatten.map {|name| name.downcase}
        other_names.each { |name| @subdivision_names[name] = subdivision_name }
      end
    end

    @subdivision_names
  end
end
