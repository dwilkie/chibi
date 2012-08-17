module TranslationHelpers
  TRANSLATIONS = {
    :could_not_find_a_friend => {
      :en => "Sorry we can't find a friend for you at this time. We'll let you know when someone comes online",
      :kh => "Som-tos pel nis min mean nek tom-nae te. Yerng neng pjeur tov nek m-dong teat nov pel mean nek tom-nae"
    },

    :anonymous_could_not_find_a_friend => {
      :en => "Sorry we can't find a friend for you at this time. Reply with your name, age, sex, city & preferred gender to try again",
      :kh => "Som-tos pel nis min mean nek tom-nae te. Pjeur chhmos, a-yu, phet, ti-tang & phet del nek jong rok derm-bei pjea-yeam m-dong teat"
    },

    :friend_unavailable => {
      :en => "#[0]: Sorry now I'm chatting with someone else. I'll chat with you later",
      :kh => "#[0]: Sorry now I'm chatting with someone else na. I'll chat with you later"
    },

    :welcome => {
      :en => {
        :en => "Welcome to Chibi! We'll help you meet a new friend! At any time you can write 'stop' to go offline",
        :kh => "Welcome to Chibi! We'll help you meet a new friend! At any time you can write 'kh' to read Khmer, 'en' to read English or 'stop' to go offline",
      },
      :kh => "Som sva-kom mok kan Chibi! Yerng chuay nek rok mit tmey! At any time you can write 'en' to read English, 'kh' to read Khmer or 'stop' to go offline",
    },

    :anonymous_new_friend_found => {
      :en => "Hi! We have found a new friend for you! Send #[0] a msg now by replying to this message",
      :kh => "Sousdey! Yerng ban rok mit tmey som-rab nek haey! Pjeur sa derm-bei chleuy torb tov #[0] ai-lov nis"
    },

    :personalized_new_friend_found => {
      :en => "Hi #[0]! We have found a new friend for you! Send #[1] a msg now by replying to this message",
      :kh => "Sousdey #[0]! Yerng ban rok mit tmey som-rab nek haey! Pjeur sa derm-bei chleuy torb tov #[1] ai-lov nis"
    },

    :anonymous_chat_has_ended => {
      :en => "INFO: Want to meet a new friend? Reply with your name, age, sex, city & preferred gender",
      :kh => "INFO: Jong rok mit tmey? Pjeur chhmos, a-yu, phet, ti-tang & phet del nek jong rok"
    },

    :chat_has_ended => {
      :en => "INFO: Want to meet a new friend? Reply with 'new'",
      :kh => "INFO: Jong rok mit tmey? Sorsay 'new'"
    },

    :logged_out_from_chat => {
      :en => "You are now offline. Chat with #[0] again by replying to this message or reply with 'new' to meet a new friend",
      :kh => "Pel nis nek jaak jenh haey. Pjeur sa derm-bei chat jea-moy #[0] m-dong teat reu sorsay 'new' derm-bei rok mit tmey teat"
    },

    :anonymous_logged_out => {
      :en => "You are now offline. Reply with your name, age, sex, city & preferred gender to meet a new friend",
      :kh => "Pel nis nek jaak jenh haey. Pjeur chhmos, a-yu, phet, ti-tang & phet del nek jong rok derm-bei rok mit tmey teat"
    },

    :logged_out => {
      :en => "You are now offline. Reply with 'new' to meet a new friend",
      :kh => "Pel nis nek jaak jenh haey. Sorsay 'new' derm-bei rok mit tmey"
    },

    :only_missing_sexual_preference_logged_out => {
      :en => "You are now offline. Reply with your preferred gender to meet a new friend",
      :kh => "Pel nis nek jaak jenh haey. Pjeur phet del nek jong rok derm-bei rok mit tmey teat"
    },

    :forward_message => {
      :en => "#[0]: #[1]",
      :kh => "#[0]: #[1]"
    },

    :anonymous_reminder => {
      :en => "Hi! Want to meet a new friend? Reply with your name, age, sex, city & preferred gender",
      :kh => "Sousdey! Jong rok mit tmey? Pjeur chhmos, a-yu, phet, ti-tang & phet del nek jong rok"
    },

    :reminder => {
      :en => "Hi #[0]! Want to meet a new friend? Reply with 'new'",
      :kh => "Sousdey #[0]! Pjeur 'new'"
    },

    :greeting_from_unknown_gender => {
      :en => "#[0]: Hi! I want to play SMS! Write back NOW to chat with ME or write 'new' to meet a new friend",
      :kh => "#[0]: Sousdey! Nhom jong rok mit leng SMS! Write back NOW to chat with ME or write 'new' to meet a new friend"
    },

    :greeting_from_male_showing_full_profile => {
      :en => "#[0]: Hi! I want to play SMS! I'm a male #[1] yo living in #[2]. Write back NOW to chat with ME or write 'new' to meet a new friend",
      :kh => "#[0]: Sousdey bart! Nhom a yu #[1] nov #[2] jong rok mit leng SMS! Write back NOW to chat with ME or write 'new' to meet a new friend"
    },

    :greeting_from_female_showing_full_profile => {
      :en => "#[0]: Hi! I want to play SMS! I'm a female #[1] yo living in #[2]. Write back NOW to chat with ME or write 'new' to meet a new friend",
      :kh => "#[0]: Sousdey ja! Nhom a yu #[1] nov #[2] jong rok mit leng SMS! Write back NOW to chat with ME or write 'new' to meet a new friend"
    },

    :greeting_from_female_showing_age => {
      :en => "#[0]: Hi! I want to play SMS! I'm a female #[1] yo. Write back NOW to chat with ME or write 'new' to meet a new friend",
      :kh => "#[0]: Sousdey ja! Nhom a yu #[1] jong rok mit leng SMS! Write back NOW to chat with ME or write 'new' to meet a new friend"
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
