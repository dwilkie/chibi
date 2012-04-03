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

      :logged_out_or_chat_has_ended => lambda {|key, options|
        notification = options[:friends_screen_name] ? "#{options[:friends_screen_name]} not replying? " : "You are now offline. "

        if options[:missing_profile_attributes].any?
          notification << "Txt us "
          options[:missing_profile_attributes].first == :looking_for ? notification << "the " : notification << "ur "

          translated_missing_attributes = []
          options[:missing_profile_attributes].each do |attribute|
            translated_missing_attributes << User.human_attribute_name(attribute, :locale => :en).downcase
          end

          notification << translated_missing_attributes.to_sentence(:locale => :en)
          notification << " to "
        else
          notification << "Txt 'new' to"
        end

        notification << "meet someone new"
      }
    }
  }
}
