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

  after_create :locate

  # long running task
  def locate!(address)
    self.address = address
    if locatable?
      localized = localize_address!
      geocode
      reverse_geocode if latitude? && longitude? && (latitude_changed? || longitude_changed?)
    end
    localized
  end

  def country_code
    raw_country_code = read_attribute(:country_code)
    raw_country_code.to_s.downcase if raw_country_code
  end

  private

  def locatable?
    address.present? && country_code.present?
  end

  def locate
    LocatorJob.perform_later(id, address) if locatable?
  end

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
    normalized_address = address.downcase
    subdivision_names.each do |subdivision_name, regexp|
      if normalized_address =~ regexp
        self.address = subdivision_name
        break
      end
    end
    $~.try(:[], 0)
  end

  def subdivision_names
    unless @subdivision_names
      @subdivision_names = {}

      country.subdivisions.values.each do |subdivision|
        subdivision_name = normalize_subdivision(subdivision["name"])
        other_names = [subdivision["names"]].flatten.map { |name| normalize_subdivision(name) }
        other_names << subdivision_name unless other_names.include?(subdivision_name)

        other_names.map! do |name|
          name.gsub!(".", "\\.")
          name
        end

        @subdivision_names[subdivision_name] = /\b(?:#{other_names.join('|')})\b/
      end
    end

    @subdivision_names
  end

  def normalize_subdivision(name)
    name.gsub(/\[.+\]/, "").strip.downcase
  end
end
