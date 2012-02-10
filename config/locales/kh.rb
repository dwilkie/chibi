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
        if options[:friends_screen_name]
          notification = "Chat jea-moy #{options[:friends_screen_name]} "
          options[:logged_out] ? notification << "trov ban job & pel nis nek jaak jenh haey" : notification << "job huey"
        else
          # There's no friends screen name
          # so assume there is no chat and they logged out
          options[:logged_out] = true
          notification = "Pel nis nek jaak jenh haey"
        end

        notification << ". "

        if options[:missing_profile_attributes].any?
          notification << "Pjeur "

          translated_missing_attributes = []
          options[:missing_profile_attributes].each do |attribute|
            translated_missing_attributes << User.human_attribute_name(attribute, :locale => :kh).downcase
          end

          notification << translated_missing_attributes.to_sentence(:locale => :kh)
          notification << " d3 update profile & chat m-dong teat"
        else
          notification << "Sorsay avey moy d3 chat m-dong teat"
        end

        notification << ". Sorsay 'stop' d3 jaak jenh" unless options[:logged_out]
        notification
      }
    }
  }
}
