module MobilePhoneHelpers
  TEST_COUNTRIES = {
    :kh => {
      :prefix => "855",
      :name => :cambodia,
      :citizens => :cambodian,
      :service_providers => {
        :smart => {
          :prefixes => ["10", "69", "70", "86", "93", "98"],
          :short_code => "2442"
        },
        :beeline => {
          :prefixes => [
            "60", "66", "67", "68", "90", "23", "24", "25", "26", "32", "33",
            "34", "35", "36", "42", "43", "44", "45", "52", "53", "54",
            "55", "62", "63", "64", "65", "72", "73", "74", "75"
          ],
          :short_code => "2442"
        }
      }
    },

    :th => {
      :prefix => "66",
      :name => :thailand,
      :citizens => :thai,
      :service_providers => {}
    },

    :gb => {
      :prefix => "44",
      :name => :england,
      :citizens => :english,
      :service_providers => {}
    },

    :us => {
      :prefix => "1",
      :name => :united_states,
      :citizens => :american,
      :service_providers => {}
    }
  }

  def with_users_from_different_countries(&block)
    TEST_COUNTRIES.each do |country_code, data|
      yield(country_code.to_s, data[:prefix], data[:name], data[:citizens])
    end
  end

  def with_service_providers(&block)
    TEST_COUNTRIES.each do |country_code, data|
      data[:service_providers].each do |service_provider, properties|
        properties[:prefixes].each do |prefix|
          number_prefix = "#{data[:prefix]}#{prefix}"
          yield(service_provider, number_prefix, properties[:short_code], "#{service_provider}_#{number_prefix}_user".to_sym)
        end
      end
    end
  end
end
