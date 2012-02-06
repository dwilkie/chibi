{
  :en => {
    :messages => {
      :new_chat_started => lambda {|key, options|
        greeting = "Hi"
        greeting << " #{options[:users_name].capitalize}" if options[:users_name]

        if options[:old_friends_screen_name]
          notification = "Ur chat with #{options[:old_friends_screen_name]} has ended & u r now chatting with #{options[:friends_screen_name]}!"
        else
          notification = options[:to_user] ? "U r now chatting with #{options[:friends_screen_name]}!" : "#{options[:friends_screen_name]} wants 2 chat with u!"
          notification << " Send #{options[:friends_screen_name]} a msg now or reply with 'new' 2 chat with someone new"
        end

        greeting << "! " << notification
      },

      :could_not_start_new_chat => lambda {|key, options|
        greeting = "Hi"
        greeting << " #{options[:users_name].capitalize}" if options[:users_name]
        greeting << ", we can't find a match for u at this time. We'll let u know when someone comes online!"
      },

      :chat_has_ended => lambda {|key, options|
        notification = "Ur chat with #{options[:friends_screen_name]} has ended"
        notification << " & u r now offline" if options[:offline]
        notification << ". "

        if options[:missing_profile_attributes].any?
          notification << "Txt us "
          notification << "ur " unless options[:missing_profile_attributes].first == :looking_for

          translated_missing_attributes = []
          options[:missing_profile_attributes].each do |attribute|
            translated_missing_attributes << User.human_attribute_name(attribute, :locale => :en).downcase
          end

          notification << translated_missing_attributes.to_sentence(:locale => :en)
          notification << " 2 update ur profile & "
        else
          notification << "Send us a txt 2 "
        end

        notification << "chat again."
        notification << " Txt 'stop' 2 go offline" unless options[:offline]
        notification
      }
    }
  }
}
