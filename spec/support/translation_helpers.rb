module TranslationHelpers
  TRANSLATIONS = {
    :could_not_find_a_friend => {
      :en => "chibi: Sorry we can't find a friend for you at this time. We'll let you know when someone comes online",
      :kh => "chibi: Som-tos pel nis min mean nek tom-nae te. Yerng neng pjeur tov nek m-dong teat nov pel mean nek tom-nae"
    },

    :anonymous_could_not_find_a_friend => {
      :en => "chibi: Sorry we can't find a friend for you at this time. Txt us ur name, age, sex, city & gender ur seeking to try again",
      :kh => "chibi: Som-tos pel nis min mean nek tom-nae te. Pjeur chhmos, a-yu, phet, ti-tang & phet del nek jong rok derm-bei pjea-yeam m-dong teat"
    },

    :friend_unavailable => {
      :en => "chibi: Sorry #[0] is currently unavailable. Txt 'new' to meet someone new",
      :kh => "chibi: Som-tos pel nis #[0] min tom-nae te. Sorsay 'new' derm-bei rok mit tmey teat"
    },

    :welcome => {
      :en => {
        :en => "chibi: Welcome to Chibi! We'll help you meet a new friend! At any time you can write 'stop' to go offline",
        :kh => "chibi: Welcome to Chibi! We'll help you meet a new friend! At any time you can write 'kh' to read Khmer, 'en' to read English or 'stop' to go offline",
      },
      :kh => "chibi: Som sva-kom mok kan Chibi! Yerng chuay nek rok mit tmey! At any time you can write 'en' to read English, 'kh' to read Khmer or 'stop' to go offline",
    },

    :anonymous_new_friend_found => {
      :en => "chibi: Hi! We have found a new friend for you! Send #[0] a msg now by replying to this message",
      :kh => "chibi: Sousdey! Yerng ban rok mit tmey som-rab nek haey! Pjeur sa derm-bei chleuy torb tov #[0] ai-lov nis"
    },

    :personalized_new_friend_found => {
      :en => "chibi: Hi #[0]! We have found a new friend for you! Send #[1] a msg now by replying to this message",
      :kh => "chibi: Sousdey #[0]! Yerng ban rok mit tmey som-rab nek haey! Pjeur sa derm-bei chleuy torb tov #[1] ai-lov nis"
    },

    :anonymous_chat_has_ended => {
      :en => "chibi: #[0] not replying? Txt us ur name, age, sex, city & gender ur seeking to meet someone new",
      :kh => "chibi: #[0] min chleuy torb te? Pjeur chhmos, a-yu, phet, ti-tang & phet del nek jong rok derm-bei rok mit tmey teat"
    },

    :chat_has_ended => {
      :en => "chibi: #[0] not replying? Txt 'new' to meet someone new",
      :kh => "chibi: #[0] min chleuy torb te? Sorsay 'new' derm-bei rok mit tmey teat"
    },

    :logged_out_from_chat => {
      :en => "chibi: You are now offline. Chat with #[0] again by replying to this message or txt 'new' to meet someone new",
      :kh => "chibi: Pel nis nek jaak jenh haey. Pjeur sa derm-bei chat jea-moy #[0] m-dong teat reu sorsay 'new' derm-bei rok mit tmey teat"
    },

    :anonymous_logged_out => {
      :en => "chibi: You are now offline. Txt us ur name, age, sex, city & gender ur seeking to meet someone new",
      :kh => "chibi: Pel nis nek jaak jenh haey. Pjeur chhmos, a-yu, phet, ti-tang & phet del nek jong rok derm-bei rok mit tmey teat"
    },

    :logged_out => {
      :en => "chibi: You are now offline. Txt 'new' to meet someone new",
      :kh => "chibi: Pel nis nek jaak jenh haey. Sorsay 'new' derm-bei rok mit tmey"
    },

    :only_missing_sexual_preference_logged_out => {
      :en => "chibi: You are now offline. Txt us the gender ur seeking to meet someone new",
      :kh => "chibi: Pel nis nek jaak jenh haey. Pjeur phet del nek jong rok derm-bei rok mit tmey teat"
    },

    :forward_message => {
      :en => "#[0]: #[1]",
      :kh => "#[0]: #[1]"
    },

    :forward_message_approx => {
      :en => "#[0]: ",
      :kh => "#[0]: "
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
