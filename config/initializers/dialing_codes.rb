dialing_codes = {}
defaults = ["US", "GB", "AU", "IT", "RU", "NO"]
ISO3166::Country.all.each do |name, country_code|
  dialing_code = ISO3166::Country[country_code].country_code
  dialing_codes[dialing_code] = country_code unless dialing_codes[dialing_code] && !defaults.include?(country_code)
end

DIALING_CODES = dialing_codes
REVERSE_DIALING_CODES = DIALING_CODES.invert

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

service_provider_prefixes_with_international_dialing_code = []

SERVICE_PROVIDER_PREFIXES.each do |country_code, prefixes|
  international_dialing_code = REVERSE_DIALING_CODES[country_code.upcase]
  prefixes.keys.each do |prefix|
    service_provider_prefixes_with_international_dialing_code << international_dialing_code.to_s + prefix.to_s
  end
end

SERVICE_PROVIDER_PREFIXES_WITH_INTERNATIONAL_DIALING_CODE = service_provider_prefixes_with_international_dialing_code
