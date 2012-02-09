module TranslationHelpers
  TRANSLATIONS = {
    :new_chat_started => "replies.new_chat_started",
    :could_not_start_new_chat => "replies.could_not_start_new_chat",
    :logged_out_or_chat_has_ended => "replies.logged_out_or_chat_has_ended"
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
