module MobilePhoneHelpers
  include Torasup::Test::Helpers

  ASSERTED_REGISTERED_OPERATORS = {
    "kh" => %w{smart beeline}
  }

  TESTED_NATIONALITIES = {
    :kh => [:cambodian, :from_kampong_thom, :from_phnom_penh],
    :th => :thai,
    :gb => :english,
    :us => :american
  }

  private

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

  def asserted_default_pbx_dial_string(interpolations = {})
    asserted_dial_string = "sofia/gateway/didlogic/%{number_to_dial}"
    interpolations.each do |interpolation, value|
      asserted_dial_string.gsub!("%{#{interpolation}}", value)
    end
    asserted_dial_string
  end

  def with_operators(options = {}, &block)
    super({:only_registered => ASSERTED_REGISTERED_OPERATORS}.merge(options), &block)
  end

  def registered_operator(type)
    factory_generated_number = generate(:operator_number_with_voice)
    numbers = {}
    with_operators do |number_parts, assertions|
      number_without_padding = number_parts.join.gsub(/0+$/, "")
      if assertions["caller_id"] && factory_generated_number =~ /^#{number_without_padding}/
        numbers[factory_generated_number] = assertions
        break
      end
    end
    type == :number ? numbers.keys.first : numbers.values.first[type.to_s]
  end
end
