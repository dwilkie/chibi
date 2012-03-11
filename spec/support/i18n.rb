locales = []

Dir["#{Rails.root}/config/locales/*.yml"].each do |path|
  locales << File.basename(path, ".yml").to_sym
end

I18n.available_locales = locales
