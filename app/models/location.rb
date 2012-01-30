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
    DIALING_CODES[Phony.split(mobile_number).first] if mobile_number
  end

  # move into a background job
  def locate!
    if address.present? && country_code?
      localize_address!
      geocode
      reverse_geocode if latitude? && longitude?
    end
  end

  def country_code
    read_attribute(:country_code).to_s.upcase
  end

  def locale
    country_code.downcase.to_sym
  end

  private

  def country
    ISO3166::Country[country_code]
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
