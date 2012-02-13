{
  :kh => {
    :replies => {
      :new_chat_started => lambda {|key, options|
        greeting = "Sousdey"
        greeting << " #{options[:users_name].capitalize}" if options[:users_name]

        notification = "#{options[:friends_screen_name]} jong chat jea-moy! Chleuy torb tov #{options[:friends_screen_name]} reu ban-chhop chat daoy sorsay 'new' rok mit tmey teat"

        greeting << "! " << notification
      },

      :could_not_start_new_chat => lambda {|key, options|
        "Som-tos pel nis min mean nek tom-nae te. Yerng neng pjeur tov nek m-dong teat nov pel mean nek tom-nae"
      },


      :logged_out_or_chat_has_ended => lambda {|key, options|
        notification = options[:logged_out] ? "U r now offline." : "Ur chat session has ended."

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

        notification << "chat again with someone new"
        notification << ". Txt 'stop' 2 go offline" unless options[:logged_out]
        notification
      },

      :logged_out_or_chat_has_ended => lambda {|key, options|
        notification = options[:logged_out] ? "Pel nis nek jaak jenh haey. " : "Chat trov ban job haey. "

        if options[:missing_profile_attributes].any?
          notification << "Pjeur "

          translated_missing_attributes = []
          options[:missing_profile_attributes].each do |attribute|
            translated_missing_attributes << User.human_attribute_name(attribute, :locale => :kh).downcase
          end

          notification << translated_missing_attributes.to_sentence(:locale => :kh)
          notification << " d3 update profile & rok mit tmey teat"
        else
          notification << "Sorsay avey moy d3 rok mit tmey teat"
        end

        notification << ". Sorsay 'stop' d3 jaak jenh" unless options[:logged_out]
        notification
      }
    }
  }
}
