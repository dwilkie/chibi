module TranslationHelpers
  TRANSLATIONS = {
    :could_not_start_new_chat => {
      :en => "Sorry we can't find a friend for you at this time. We'll let you know when someone comes online",
      :kh => "Som-tos pel nis min mean nek tom-nae te. Yerng neng pjeur tov nek m-dong teat nov pel mean nek tom-nae"
    },

    :friend_unavailable => {
      :en => "Sorry #[0] is currently unavailable. Txt 'new' to meet someone new",
      :kh => "Som-tos pel nis #[0] min tom-nae te. Sorsay 'new' derm-bei rok mit tmey teat"
    },

    :welcome => {
      :en => "Welcome to Chibi! We'll help you meet a new friend! At any time you can write 'en' to read English or 'stop' to go offline",
      :kh => "Som sva-kom mok kan Chibi! Yerng chuay nek rok mit tmey! At any time you can write 'en' to read English, 'kh' to read Khmer or 'stop' to go offline"
    },

    :anonymous_new_friend_found => {
      :en => "Hi! We have found a new friend for you! Send #[0] a msg now by replying to this message",
      :kh => "Sousdey! Yerng ban rok mit tmey som-rab nek haey! Pjeur sa derm-bei chleuy torb tov #[0] ai-lov nis"
    },

    :personalized_new_friend_found => {
      :en => "Hi #[0]! We have found a new friend for you! Send #[1] a msg now by replying to this message",
      :kh => "Sousdey #[0]! Yerng ban rok mit tmey som-rab nek haey! Pjeur sa derm-bei chleuy torb tov #[1] ai-lov nis"
    },

    :personalized_new_chat_started => {
      :en => "Hi [0]! #[1] wants to chat with u! Send #[1] a msg now by replying to this message",
      :kh => "Sousdey #[0]! #[1] jong chat jea-moy! Pjeur sa derm-bei chleuy torb tov #[1] ai-lov nis"
    },

    :anonymous_new_chat_started => {
      :en => "Hi! #[0] wants to chat with u! Send #[0] a msg now by replying to this message",
      :kh => "Sousdey! #[0] jong chat jea-moy! Pjeur sa derm-bei chleuy torb tov #[0] ai-lov nis"
    },

    :anonymous_chat_has_ended => {
      :en => "#[0] not replying? Txt us ur name, age, sex, city & gender ur seeking to meet someone new",
      :kh => "#[0] min chleuy torb te? Pjeur chhmos, a-yu, phet, ti-tang & phet del nek jong rok derm-bei rok mit tmey teat"
    },

    :chat_has_ended => {
      :en => "#[0] not replying? Txt 'new' to meet someone new",
      :kh => "#[0] min chleuy torb te? Sorsay 'new' derm-bei rok mit tmey teat"
    },

    :logged_out => {
      :en => "You are now offline. Txt 'new' to meet someone new",
      :kh => "Pel nis nek jaak jenh haey. Sorsay 'new' derm-bei rok mit tmey teat"
    },

    :anonymous_logged_out => {
      :en => "You are now offline. Txt us ur name, age, sex, city & gender ur seeking to meet someone new",
      :kh => "Pel nis nek jaak jenh haey. Pjeur chhmos, a-yu, phet, ti-tang & phet del nek jong rok derm-bei rok mit tmey teat"
    },

    :only_missing_sexual_preference_logged_out => {
      :en => "You are now offline. Txt us the gender ur seeking to meet someone new",
      :kh => "Pel nis nek jaak jenh haey. Pjeur phet del nek rok derm-bei jong rok mit tmey teat"
    },

    :forward_message => {
      :en => "#[0]: #[1]",
      :kh => "#[0]: #[1]"
    }
  }

  def spec_translate(key, locale, *interpolations)
    translations = TRANSLATIONS[key]
    raise("Translation '#{key}' not found. Add it to #{__FILE__}") unless translations.present?
    # special case:
    # if the users locale is :gb test the default locale
    translation = translations[locale == :gb ? :en : locale].dup
    interpolations.each_with_index do |interpolation, index|
      raise("Interpolation: '#{interpolation}' is missing inside '#{key}'") unless translation.include?("#[#{index}]")
      translation.gsub!("#[#{index}]", interpolation)
    end
    translation
  end
end
