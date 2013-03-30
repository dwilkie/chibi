module MobilePhoneHelpers
  TEST_COUNTRIES = {
    :kh => {
      :prefix => "855",
      :name => :cambodia,
      :citizens => :cambodian,
      :area_codes => {
        "23" => "Phnom Penh",
        "24" => "Kandal",
        "25" => "Kampong Speu",
        "26" => "Kampong Chhnang",
        "32" => "Takeo",
        "33" => "Kampot",
        "34" => "Sihanoukville",
        "35" => "Koh Kong",
        "36" => "Kep",
        "42" => "Kampong Cham",
        "43" => "Prey Veng",
        "44" => "Svay Rieng",
        "52" => "Pursat",
        "53" => "Battambang",
        "54" => "Banteay Meanchey",
        "55" => "Pailin",
        "62" => "Kampong Thom",
        "63" => "Siem Reap",
        "64" => "Preah Vihear",
        "65" => "Oddar Meanchey",
        "72" => "Kratie",
        "73" => "Mondulkiri",
        "74" => "Stung Treng",
        "75" => "Ratanakiri"
      },
      :service_providers => {
        :smart => {
          :prefixes => ["10", "69", "70", "86", "93", "96", "98"],
          :area_code_prefixes => [],
          :short_code => "2442"
        },
        :beeline => {
          :prefixes => ["60", "66", "67", "68", "90"],
          :area_code_prefixes => ["46"],
          :short_code => "2442"
        },
        :hello => {
          :prefixes => ["15", "16", "81", "87"],
          :area_code_prefixes => ["45"],
          :short_code => "2442"
        }
      }
    },

    :th => {
      :prefix => "66",
      :name => :thailand,
      :citizens => :thai,
      :area_codes => {},
      :service_providers => {}
    },

    :gb => {
      :prefix => "44",
      :name => :england,
      :citizens => :english,
      :area_codes => {},
      :service_providers => {}
    },

    :us => {
      :prefix => "1",
      :name => :united_states,
      :citizens => :american,
      :area_codes => {},
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
        prefixes = properties[:prefixes]
        properties[:area_code_prefixes].each do |area_code_prefix|
          data[:area_codes].each do |area_code, location|
            prefixes << "#{area_code}#{area_code_prefix}"
          end
        end
        prefixes.each do |prefix|
          padding = "0" * (8 - prefix.length)
          number_prefix = "#{data[:prefix]}#{prefix}"
          yield(service_provider, number_prefix, properties[:short_code], "#{service_provider}_#{number_prefix}".to_sym, padding)
        end
      end
    end
  end
end
