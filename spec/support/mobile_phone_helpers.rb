module MobilePhoneHelpers
  include Torasup::Test::Helpers

  ASSERTED_REGISTERED_OPERATORS = {
    "kh" => %w{smart beeline hello}
  }

  TESTED_NATIONALITIES = {
    :kh => [:cambodian, :from_kampong_thom, :from_phnom_penh],
    :th => :thai,
    :gb => :english,
    :us => :american
  }

  def with_users_from_different_countries(&block)
    TESTED_NATIONALITIES.each do |country_code, localities|
      [localities].flatten.each do |locality|
        location = locality.to_s.gsub(/^from\_/, "")
        area = location.titleize if $~
        yield(locality, country_code, area)
      end
    end
  end

  def yaml_file(filename)
    File.join(File.dirname(__FILE__), "/#{filename}")
  end

  def pstn_data(custom_spec = nil)
    super("custom_operators_spec.yaml")
  end

  def with_operators(&block)
    super(:only_registered => ASSERTED_REGISTERED_OPERATORS, &block)
  end

  def registered_operator_number
    numbers = []
    with_operators do |number_parts, assertions|
      numbers << number_parts.join if assertions["caller_id"]
    end
    numbers.first
  end
end
