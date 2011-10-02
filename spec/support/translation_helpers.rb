module TranslationHelpers
  TRANSLATIONS = {
    :suggestions => "messages.suggestions"
  }

  def spec_translate(key, options = {})
    translation = TRANSLATIONS[key]
    if translation.is_a?(String)
      I18n.t(translation, options)
    else
      raise "Translation '#{key}' not found. Add it to #{__FILE__}"
    end
  end
end
