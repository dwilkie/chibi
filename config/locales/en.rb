{
  :en => {
    :replies => {

      :welcome => lambda {|key, options|
        "Welcome to Chibi! We'll help you meet a new friend! At any time you can write 'en' to read English or 'stop' to go offline"
      },

      :new_chat_started => lambda {|key, options|
        greeting = "Hi"
        greeting << " #{options[:users_name].capitalize}" if options[:users_name]

        instructions = "Send #{options[:friends_screen_name]} a msg now by replying to this message"

        notification = options[:to_initiator] ? "We have found a new friend for you! " : "#{options[:friends_screen_name]} wants to chat with u! "

        greeting << "! " << notification << instructions
      },

      :could_not_start_new_chat => lambda {|key, options|
        "Sorry we can't find a friend for you at this time. We'll let you know when someone comes online"
      },

      :how_to_start_a_new_chat => lambda {|key, options|

        default_instructions = "Txt 'new' to "

        case options[:action]
        when :logout
          notification = "You are now offline. "
        when :no_answer
          notification = "#{options[:friends_screen_name]} not replying? "
        when :friend_unavailable
          notification = "Sorry #{options[:friends_screen_name]} is currently unavailable. "
          instructions = default_instructions
        end

        if !instructions && options[:missing_profile_attributes].any?
          instructions = "Txt us "
          options[:missing_profile_attributes].first == :looking_for ? instructions << "the " : instructions << "ur "

          translated_missing_attributes = []
          options[:missing_profile_attributes].each do |attribute|
            translated_missing_attributes << User.human_attribute_name(attribute, :locale => :en).downcase
          end

          instructions << translated_missing_attributes.to_sentence(:locale => :en)
          instructions << " to "
        else
          instructions ||= default_instructions
        end

        instructions << "meet someone new"
        notification << instructions
      }
    }
  }
}
