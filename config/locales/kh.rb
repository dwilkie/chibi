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

      :how_to_start_a_new_chat => lambda {|key, options|

        default_instructions = "Sorsay 'new' "

        case options[:action]
        when :logout
          notification = "Pel nis nek jaak jenh haey. "
        when :no_answer
          notification = "#{options[:friends_screen_name]} min chleuy torb te? "
        when :friend_unavailable
          notification = "Som-tos pel nis #{options[:friends_screen_name]} min tom-nae te. "
          instructions = default_instructions
        end

        if !instructions && options[:missing_profile_attributes].any?
          instructions = "Pjeur "

          translated_missing_attributes = []
          options[:missing_profile_attributes].each do |attribute|
            translated_missing_attributes << User.human_attribute_name(attribute, :locale => :kh).downcase
          end

          instructions << translated_missing_attributes.to_sentence(:locale => :kh)
          instructions << " "
        else
          instructions ||= default_instructions
        end

        instructions << "derm-bei rok mit tmey teat"
        notification << instructions
      }
    }
  }
}
