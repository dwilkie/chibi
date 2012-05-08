{
  :kh => {
    :replies => {

      :greetings => lambda {|key, options|

        formatted_friends_name = " #{options[:friends_name].to_s.capitalize}" if options[:friends_name]

        greetings = []

        greeting_starters = ["Sousdey", "Hi"]
        ice_breakers = ["Soksabay te?", "Kom-pong tver ey?", nil]
        greeting_enders = ["Jong chat moy nyom ort?", "Jong leng sms ort?", nil]

        greeting_starters.each do |greeting_starter|
          ice_breakers.each do |ice_breaker|
            ice_breaker = " #{ice_breaker}" if ice_breaker
            greeting_enders.each do |greeting_ender|
              greeting_ender = " #{greeting_ender}" if greeting_ender
              greetings << "#{greeting_starter}!#{ice_breaker}#{greeting_ender}"
              greetings << "#{greeting_starter}#{formatted_friends_name}!#{ice_breaker}#{greeting_ender}" if formatted_friends_name
            end
          end
        end

        greetings
      },

      :welcome => lambda {|key, options|
        "chibi: Som sva-kom mok kan Chibi! Yerng chuay nek rok mit tmey! At any time you can write 'en' to read English, 'kh' to read Khmer or 'stop' to go offline"
      },

      :new_chat_started => lambda {|key, options|
        greeting = "chibi: Sousdey"
        greeting << " #{options[:users_name].capitalize}" if options[:users_name]

        greeting << "! " << "Yerng ban rok mit tmey som-rab nek haey! Pjeur sa derm-bei chleuy torb tov #{options[:friends_screen_name]} ai-lov nis"
      },

      :how_to_start_a_new_chat => lambda {|key, options|

        default_instructions = "Sorsay 'new' "
        default_outcome = "derm-bei rok mit tmey teat"

        case options[:action]
        when :logout
          notification = "Pel nis nek jaak jenh haey. "
          instructions = "Pjeur sa derm-bei chat jea-moy #{options[:friends_screen_name]} m-dong teat reu #{default_instructions.downcase}" if options[:friends_screen_name]
        when :no_answer
          notification = "#{options[:friends_screen_name]} min chleuy torb te? "
        when :friend_unavailable
          notification = "Som-tos pel nis #{options[:friends_screen_name]} min tom-nae te. "
          instructions = default_instructions
        when :could_not_find_a_friend
          notification = "Som-tos pel nis min mean nek tom-nae te. "
          default_instructions = ""
          default_instructions_outcome = "derm-bei pjea-yeam m-dong teat"
          custom_or_no_instructions_outcome = "Yerng neng pjeur tov nek m-dong teat nov pel mean nek tom-nae"
        end

        if !instructions && options[:missing_profile_attributes].try(:any?)
          instructions = "Pjeur "

          translated_missing_attributes = []
          options[:missing_profile_attributes].each do |attribute|
            translated_missing_attributes << User.human_attribute_name(attribute, :locale => :kh).downcase
          end

          instructions << translated_missing_attributes.to_sentence(:locale => :kh)
          instructions << " "

          outcome = default_instructions_outcome
        else
          instructions ||= default_instructions
          outcome = custom_or_no_instructions_outcome
        end

        outcome ||= default_outcome
        "chibi: " << notification << instructions << outcome
      }
    }
  }
}
