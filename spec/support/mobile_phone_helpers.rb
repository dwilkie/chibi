module MobilePhoneHelpers
  include Torasup::Test::Helpers

  ASSERTED_REGISTERED_OPERATORS = {
    :kh => ["smart", "beeline", "hello"]
  }

  TEST_COUNTRIES = {
    :kh => {
      :name => :cambodia,
      :citizens => :cambodian,
    },

    :th => {
      :name => :thailand,
      :citizens => :thai
    },

    :gb => {
      :name => :england,
      :citizens => :english
    },

    :us => {
      :name => :united_states,
      :citizens => :american
    }
  }

  def with_users_from_different_countries(&block)
    TEST_COUNTRIES.each do |country_code, data|
      yield(country_code.to_s, data[:prefix], data[:name], data[:citizens])
    end
  end

  def yaml_file(filename)
    File.join(File.dirname(__FILE__), "/#{filename}")
  end

  def pstn_data(custom_file = nil)
    super("custom_operators_spec.yaml")
  end

  def with_operator_data(country_id, options = {}, &block)
    super(country_id, options.merge(:only_registered => ASSERTED_REGISTERED_OPERATORS), &block)
  end

#  def with_service_providers(&block)
#    TEST_COUNTRIES.each do |country_code, data|
#      data[:service_providers].each do |service_provider, properties|
#        prefixes = properties[:prefixes]
#        properties[:area_code_prefixes].each do |area_code_prefix|
#          data[:area_codes].each do |area_code, location|
#            prefixes << "#{area_code}#{area_code_prefix}"
#          end
#        end
#        prefixes.each do |prefix|
#          padding = "0" * (8 - prefix.length)
#          number_prefix = "#{data[:prefix]}#{prefix}"
#          yield(service_provider, number_prefix, properties[:short_code], "#{service_provider}_#{number_prefix}".to_sym, padding)
#        end
#      end
#    end
#  end
end
