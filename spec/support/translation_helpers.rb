module TranslationHelpers
  TRANSLATIONS = {
    :new_chat_started => "messages.new_chat_started",
    :could_not_start_new_chat => "messages.could_not_start_new_chat"
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
