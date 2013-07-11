module TranslationHelpers
  TRANSLATIONS = {
    :forward_message => {
      :en => "#[0]: #[1]",
      :kh => "#[0]: #[1]"
    },

    :forward_message_approx => {
      :en => "#[0]: ",
      :kh => "#[0]: "
    },

    :contact_me => {
      :en => "#[0]:.+#[1]",
      :kh => "#[0]:.+#[1]"
    },

    :anonymous_reminder => {
      :en => "^(?:.+)\\:\\s.+",
      :kh => "^(?:.+)\\:\\s.+"
    }
  }

  def spec_translate(key, locale, *interpolations)
    translations = TRANSLATIONS[key]
    raise("Translation '#{key}' not found. Add it to #{__FILE__}") unless translations.present?
    # special case:
    # if the users locale is :gb test the default locale
    sub_locales = []
    [locale].flatten.each do |sub_locale|
      sub_locale.to_sym == :gb ? sub_locales << :en : sub_locales << sub_locale.to_sym
    end

    translation = translations[sub_locales.first]
    translation = translation[sub_locales.last] if translation.is_a?(Hash)
    translation = translation.dup

    interpolations.each_with_index do |interpolation, index|
      raise("Interpolation: '#{interpolation}' is missing inside '#{key}'") unless translation.include?("#[#{index}]")
      translation.gsub!("#[#{index}]", interpolation)
    end
    translation
  end
end
