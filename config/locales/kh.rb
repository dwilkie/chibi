{
  :kh => {
    :replies => {
      :greeting => lambda {|key, options|
        if options[:friend].try(:male?)
          greeting_suffix = " bart"
        elsif options[:friend].try(:female?)
          greeting_suffix = " ja"
        end
        "Sousdey#{greeting_suffix}"
      },

      :welcome => lambda {|key, options|
        "Som sva-kom mok kan Chibi! Yerng chuay nek rok mit tmey! At any time you can write 'en' to read English, 'kh' to read Khmer or 'stop' to go offline"
      },

      :new_chat_started => lambda {|key, options|
        greeting = "Sousdey"
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
          notification = "INFO: Jong chat jea-moy mit tmey? "
        when :friend_unavailable
          notification = "Som-tos pel nis #{options[:friends_screen_name]} min tom-nae te. "
          instructions = default_instructions
        when :could_not_find_a_friend
          notification = "Som-tos pel nis min mean nek tom-nae te. "
          default_instructions = ""
          default_instructions_outcome = "derm-bei pjea-yeam m-dong teat"
          custom_or_no_instructions_outcome = "Yerng neng pjeur tov nek m-dong teat nov pel mean nek tom-nae"
        when :reminder
          greeting = I18n.t("replies.greeting", :locale => :kh)
          opener = ["Jong rok mit tmey?", "Jong leng sms?"].sample
          notification = "#{greeting} #{opener} "
          default_instructions_outcome = custom_or_no_instructions_outcome = ["derm-bei rok mit tmey", "derm-bei chaab-pderm", "derm-bei pjea-yeam", "derm-bei sak-lbong"].sample
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
        notification << instructions << outcome
      }
    }
  }
}
