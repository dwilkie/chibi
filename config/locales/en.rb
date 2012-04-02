{
  :en => {
    :replies => {
      :new_chat_started => lambda {|key, options|
        greeting = "Hi"
        greeting << " #{options[:users_name].capitalize}" if options[:users_name]

        notification = "#{options[:friends_screen_name]} wants 2 chat with u! Send #{options[:friends_screen_name]} a msg now or reply with 'new' 2 meet someone new"

        greeting << "! " << notification
      },

      :could_not_start_new_chat => lambda {|key, options|
        "Sorry we can't find a friend for u at this time. We'll let u know when someone comes online"
      },

      :logged_out_or_chat_has_ended => lambda {|key, options|
        notification = options[:logged_out] ? "U r now offline. " : "Ur chat session has ended. "

        if options[:missing_profile_attributes].any?
          notification << "Txt us "
          options[:missing_profile_attributes].first == :looking_for ? notification << "the " : notification << "ur "

          translated_missing_attributes = []
          options[:missing_profile_attributes].each do |attribute|
            translated_missing_attributes << User.human_attribute_name(attribute, :locale => :en).downcase
          end

          notification << translated_missing_attributes.to_sentence(:locale => :en)
          notification << " 2 update ur profile & "
        else
          notification << "Send us a txt 2 "
        end

        notification << "meet someone new"
        notification << ". Txt 'stop' 2 go offline" unless options[:logged_out]
        notification
      }
    }
  }
}
