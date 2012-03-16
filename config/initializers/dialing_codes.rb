dialing_codes = {}
defaults = ["US", "GB", "AU", "IT", "RU", "NO"]
ISO3166::Country.all.each do |name, country_code|
  dialing_code = ISO3166::Country[country_code].country_code
  dialing_codes[dialing_code] = country_code unless dialing_codes[dialing_code] && !defaults.include?(country_code)
end

DIALING_CODES = dialing_codes

service_provider_prefixes = {}

TSP::TelecomServiceProvider.all.each do |country_code, service_providers|
  country = service_provider_prefixes[country_code] = {}
  service_providers.each do |service_provider, info|
    info["prefixes"].each do |prefix|
      country[prefix] = info["short_code"]
    end
  end
end

SERVICE_PROVIDER_PREFIXES = service_provider_prefixes
