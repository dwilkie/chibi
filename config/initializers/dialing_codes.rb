dialing_codes = {}
defaults = ["US", "JE", "AU", "IT", "RU", "NO"]
ISO3166::Country.all.each do |name, country_code|
  dialing_code = ISO3166::Country[country_code].country_code
  dialing_codes[dialing_code] = country_code unless dialing_codes[dialing_code] && !defaults.include?(country_code)
end

Location::DIALING_CODES = dialing_codes

