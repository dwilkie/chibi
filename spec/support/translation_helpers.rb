module TranslationHelpers
  TRANSLATIONS = {
    :could_not_start_new_chat => {
      :en => "Sorry we can't find a match for u at this time. We'll let u know when someone comes online",
      :kh => "Som-tos pel nis min mean nek tom-nae te. Yerng neng pjeur tov nek m-dong teat nov pel mean nek tom-nae"
    },

    :anonymous_user_logs_out => {
      :en => "U r now offline. Txt us ur name, age, city, sex & gender ur seeking 2 update ur profile & chat again",
      :kh => "Pel nis nek jaak jenh haey. Pjeur chhmos, a-yu, ti-tang, phet & avey del nek rok d3 update profile & chat m-dong teat"
    },

    :personalized_new_chat_started => {
      :en => "Hi [0]! #[1] wants 2 chat with u! Send #[1] a msg now or reply with 'new' 2 chat with someone new",
      :kh => "Sousdey #[0]! #[1] jong chat jea-moy! Chleuy torb tov #[1] reu ban-chhop chat daoy sorsay 'new' rok mit tmey teat"
    },

    :anonymous_new_chat_started => {
      :en => "Hi! #[0] wants 2 chat with u! Send #[0] a msg now or reply with 'new' 2 chat with someone new",
      :kh => "Sousdey! #[0] jong chat jea-moy! Chleuy torb tov #[0] reu ban-chhop chat daoy sorsay 'new' rok mit tmey teat"
    },

    :logged_out_and_chat_has_ended => {
      :en => "Ur chat with #[0] has ended & u r now offline. Send us a txt 2 chat again",
      :kh => "Chat jea-moy #[0] trov ban job & pel nis nek jaak jenh haey. Sorsay avey moy d3 chat m-dong teat"
    },

    :anonymous_logged_out_and_chat_has_ended => {
      :en => "Ur chat with #[0] has ended & u r now offline. Txt us ur name, age, city, sex & gender ur seeking 2 update ur profile & chat again",
      :kh => "Chat jea-moy #[0] trov ban job & pel nis nek jaak jenh haey. Pjeur chhmos, a-yu, ti-tang, phet & avey del nek rok d3 update profile & chat m-dong teat"
    },

    :chat_has_ended => {
      :en => "Ur chat with #[0] has ended. Send us a txt 2 chat again. Txt 'stop' 2 go offline",
      :kh => "Chat jea-moy #[0] job huey. Sorsay avey moy d3 chat m-dong teat. Sorsay 'stop' d3 jaak jenh"
    },

    :anonymous_logged_out => {
      :en => "U r now offline. Txt us ur name, age, city, sex & gender ur seeking 2 update ur profile & chat again",
      :kh => "Pel nis nek jaak jenh haey. Pjeur chhmos, a-yu, ti-tang, phet & avey del nek rok d3 update profile & chat m-dong teat"
    },

    :only_missing_sexual_preference_logged_out => {
      :en => "U r now offline. Txt us the gender ur seeking 2 update ur profile & chat again",
      :kh => "Pel nis nek jaak jenh haey. Pjeur avey del nek rok d3 update profile & chat m-dong teat"
    },

    :anonymous_chat_has_ended => {
      :en => "Ur chat with #[0] has ended. Txt us ur name, age, city, sex & gender ur seeking 2 update ur profile & chat again. Txt 'stop' 2 go offline",
      :kh => "Chat jea-moy #[0] job huey. Pjeur chhmos, a-yu, ti-tang, phet & avey del nek rok d3 update profile & chat m-dong teat. Sorsay 'stop' d3 jaak jenh"
    },

    :forward_message => {
      :en => "#[0]: #[1]",
      :kh => "#[0]: #[1]"
    }
  }

  def spec_translate(key, locale, *interpolations)
    translations = TRANSLATIONS[key]
    raise("Translation '#{key}' not found. Add it to #{__FILE__}") unless translations.present?
    translation = translations[locale].dup
    interpolations.each_with_index do |interpolation, index|
      translation.gsub!("#[#{index}]", interpolation)
    end
    translation
  end
end
