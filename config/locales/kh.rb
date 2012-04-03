{
  :kh => {
    :replies => {

      :welcome => lambda {|key, options|
        "Som sva-kom mok kan Chibi! Yerng chuay nek rok mit tmey! At any time you can write 'en' to read English, 'kh' to read Khmer or 'stop' to go offline"
      },

      :new_chat_started => lambda {|key, options|
        greeting = "Sousdey"
        greeting << " #{options[:users_name].capitalize}" if options[:users_name]

        instructions = "Pjeur sa derm-bei chleuy torb tov #{options[:friends_screen_name]} ai-lov nis"

        notification = options[:to_initiator] ? "Yerng ban rok mit tmey som-rab nek haey! " : "#{options[:friends_screen_name]} jong chat jea-moy! "

        greeting << "! " << notification << instructions
      },

      :could_not_start_new_chat => lambda {|key, options|
        "Som-tos pel nis min mean nek tom-nae te. Yerng neng pjeur tov nek m-dong teat nov pel mean nek tom-nae"
      },

      :logged_out_or_chat_has_ended => lambda {|key, options|
        notification = options[:friends_screen_name] ? "#{options[:friends_screen_name]} min chleuy torb te? " : "Pel nis nek jaak jenh haey. "

        if options[:missing_profile_attributes].any?
          notification << "Pjeur "

          translated_missing_attributes = []
          options[:missing_profile_attributes].each do |attribute|
            translated_missing_attributes << User.human_attribute_name(attribute, :locale => :kh).downcase
          end

          notification << translated_missing_attributes.to_sentence(:locale => :kh)
          notification << " "
        else
          notification << "Sorsay 'new' "
        end

        notification << "derm-bei rok mit tmey teat"
      }
    }
  }
}
