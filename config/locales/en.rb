{
  :en => {
    :replies => {
      :greetings => lambda {|key, options|

        formatted_friends_name = " #{options[:friends_name].to_s.capitalize}" if options[:friends_name]

        greetings = []

        greeting_starters = ["Hi", "Hey", "Hello"]
        ice_breakers = ["How r u?", "What r u doing?", nil]
        greeting_enders = ["Wanna chat with me?", nil]

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
        notification = "Welcome to Chibi! We'll help you meet a new friend! At any time you can write "

        default_locale = I18n.t("play_path_prefix", :locale => options[:default_locale])

        unless default_locale == "en"
          default_language = I18n.t("language", :locale => options[:default_locale])
          notification << "'#{default_locale}' to read #{default_language}, 'en' to read English or "
        end

        notification << "'stop' to go offline"
      },

      :new_chat_started => lambda {|key, options|
        greeting = "Hi"
        greeting << " #{options[:users_name].capitalize}" if options[:users_name]

        greeting << "! " << "We have found a new friend for you! Send #{options[:friends_screen_name]} a msg now by replying to this message"
      },

      :how_to_start_a_new_chat => lambda {|key, options|

        default_instructions = "Txt 'new' "
        default_outcome = "to meet someone new"

        case options[:action]
        when :logout
          notification = "You are now offline. "
          instructions = "Chat with #{options[:friends_screen_name]} again by replying to this message or #{default_instructions.downcase}" if options[:friends_screen_name]
        when :no_answer
          notification = "#{options[:friends_screen_name]} not replying? "
        when :friend_unavailable
          notification = "Sorry #{options[:friends_screen_name]} is currently unavailable. "
          instructions = default_instructions
        when :could_not_find_a_friend
          notification = "Sorry we can't find a friend for you at this time. "
          default_instructions = ""
          default_instructions_outcome = "to try again"
          custom_or_no_instructions_outcome = "We'll let you know when someone comes online"
        end

        if !instructions && options[:missing_profile_attributes].try(:any?)
          instructions = "Txt us "
          options[:missing_profile_attributes].first == :looking_for ? instructions << "the " : instructions << "ur "

          translated_missing_attributes = []
          options[:missing_profile_attributes].each do |attribute|
            translated_missing_attributes << User.human_attribute_name(attribute, :locale => :en).downcase
          end

          instructions << translated_missing_attributes.to_sentence(:locale => :en)
          instructions << " "

          outcome = default_instructions_outcome
        else
          instructions ||= default_instructions
          outcome = custom_or_no_instructions_outcome
        end

        outcome ||= default_outcome
        notification << instructions << outcome
      }
    }
  }
}
