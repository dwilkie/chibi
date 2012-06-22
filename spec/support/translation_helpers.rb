module TranslationHelpers
  TRANSLATIONS = {
    :could_not_find_a_friend => {
      :en => "Sorry we can't find a friend for you at this time. We'll let you know when someone comes online",
      :kh => "Som-tos pel nis min mean nek tom-nae te. Yerng neng pjeur tov nek m-dong teat nov pel mean nek tom-nae"
    },

    :anonymous_could_not_find_a_friend => {
      :en => "Sorry we can't find a friend for you at this time. Txt ur name, age, sex, city & gender ur seeking to try again",
      :kh => "Som-tos pel nis min mean nek tom-nae te. Pjeur chhmos, a-yu, phet, ti-tang & phet del nek jong rok derm-bei pjea-yeam m-dong teat"
    },

    :friend_unavailable => {
      :en => "Sorry #[0] is currently unavailable. Txt 'new' to meet someone new",
      :kh => "Som-tos pel nis #[0] min tom-nae te. Sorsay 'new' derm-bei rok mit tmey teat"
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
      :en => "INFO: Want to chat with someone new? Txt ur name, age, sex, city & gender ur seeking to meet someone new",
      :kh => "INFO: Jong chat jea-moy mit tmey? Pjeur chhmos, a-yu, phet, ti-tang & phet del nek jong rok derm-bei rok mit tmey teat"
    },

    :chat_has_ended => {
      :en => "INFO: Want to chat with someone new? Txt 'new' to meet someone new",
      :kh => "INFO: Jong chat jea-moy mit tmey? Sorsay 'new' derm-bei rok mit tmey teat"
    },

    :logged_out_from_chat => {
      :en => "You are now offline. Chat with #[0] again by replying to this message or txt 'new' to meet someone new",
      :kh => "Pel nis nek jaak jenh haey. Pjeur sa derm-bei chat jea-moy #[0] m-dong teat reu sorsay 'new' derm-bei rok mit tmey teat"
    },

    :anonymous_logged_out => {
      :en => "You are now offline. Txt ur name, age, sex, city & gender ur seeking to meet someone new",
      :kh => "Pel nis nek jaak jenh haey. Pjeur chhmos, a-yu, phet, ti-tang & phet del nek jong rok derm-bei rok mit tmey teat"
    },

    :logged_out => {
      :en => "You are now offline. Txt 'new' to meet someone new",
      :kh => "Pel nis nek jaak jenh haey. Sorsay 'new' derm-bei rok mit tmey"
    },

    :only_missing_sexual_preference_logged_out => {
      :en => "You are now offline. Txt the gender ur seeking to meet someone new",
      :kh => "Pel nis nek jaak jenh haey. Pjeur phet del nek jong rok derm-bei rok mit tmey teat"
    },

    :forward_message => {
      :en => "#[0]: #[1]",
      :kh => "#[0]: #[1]"
    },

    :anonymous_reminder_approx => {
      :en => "Txt ur name, age, sex, city & gender ur seeking",
      :kh => "Pjeur chhmos, a-yu, phet, ti-tang & phet del nek jong rok"
    },

    :reminder_approx => {
      :en => "Txt 'new' to",
      :kh => "Sorsay 'new' derm-bei"
    },

    :greeting_from_unknown_gender => {
      :en => "#[0]: Hi",
      :kh => "#[0]: Sousdey"
    },

    :greeting_from_male => {
      :en => "#[0]: Hi",
      :kh => "#[0]: Sousdey bart"
    },

    :greeting_from_female => {
      :en => "#[0]: Hi",
      :kh => "#[0]: Sousdey ja"
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
