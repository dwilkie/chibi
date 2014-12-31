module TranslationHelpers
  TRANSLATIONS = {
    :forward_message => {
      :en => "#[0]: #[1]",
      :kh => "#[0]: #[1]",
      :ph => "#[0]: #[1]"
    },

    :forward_message_approx => {
      :en => "#[0]: ",
      :kh => "#[0]: ",
      :ph => "#[0]: "
    },

    :contact_me => {
      :en => "#[0]:.+#[1]",
      :kh => "#[0]:.+#[1]",
      :ph => "#[0]:.+#[1]"
    },

    :anonymous_reminder => {
      :en => "^(?:.+)\\:\\s.+",
      :kh => "^(?:.+)\\:\\s.+",
      :ph => "^(?:.+)\\:\\s.+"
    },

    :not_enough_credit => {
      :en => "Hello! Want to meet new friends? Please top up your account to get 24hrs free SMS on 2442",
      :kh => "Sousdey! Want to meet new friends? Please top up your account to get 24hrs free SMS on 2442",
      :ph => "Gusto mo ba ng bagong kaibigan? Mag-load na at magtext sa 2442!",
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
