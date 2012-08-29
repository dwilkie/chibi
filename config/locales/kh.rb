{
  :kh => {
    :replies => {
      :greeting => lambda {|key, options|

        sender = options[:friend]
        recipient = options[:recipient]

        sender_name = " #{sender.screen_id}" if sender.try(:name)
        recipient_name = " #{recipient.screen_id}" if recipient.try(:name)

        i_ams = ["Nhom", "Knhom", "Nhum", "Nhom chhmous", "I am", "I'm", "m", "My name"]
        i_am = i_ams.sample

        sender_intro = " #{i_am}#{sender_name}" if sender_name

        greetings = ["Sousdey", "Hi", "Hello"]
        greeting = greetings.sample

        greeting_punctuations = ["!", ","]
        greeting_punctuation = greeting_punctuations.sample

        recipient_starter = "#{greeting}#{recipient_name}#{greeting_punctuation}"

        introductions = [
          "#{recipient_starter} Soksabay te?#{sender_intro}",
          "#{recipient_starter} Nhom rikreay nas del ban skal.",
          "#{recipient_starter} Nek leng sms chea moy nhom te?",
          "#{recipient_starter} Nhom jorng skoul nek ban te?",
          "Oh can i make friend with you#{recipient_name}?",
          "#{recipient_starter} Nhom#{sender_name} jong rok met leng SMS! Som chleuy tob vinh!",
          "#{recipient_starter} Jong chat chea moy nhom ot?",
          "#{greeting}#{greeting_punctuation}#{sender_intro} sousdey#{recipient_name} how a u 2 day?",
          "#{recipient_starter} how a you doing now?#{sender_intro}",
          "#{recipient_starter}#{sender_intro}",
          "I want to make friend with ok te#{recipient_name}?"
        ]

        introductions.sample.strip
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
        default_outcome = ""

        case options[:action]
        when :logout
          notification = "Pel nis nek jaak jenh haey. "
          instructions = "Pjeur sa derm-bei chat jea-moy #{options[:friends_screen_name]} m-dong teat reu #{default_instructions.downcase}" if options[:friends_screen_name]
          default_outcome = "derm-bei rok mit tmey teat"
        when :no_answer
          notification = "Jong rok mit tmey? "
        when :friend_unavailable
          notification = "#{options[:friends_screen_name]}: Sorry now I'm chatting with someone else na. I'll chat with you later"
          instructions = ""
          default_outcome = ""
        when :could_not_find_a_friend
          notification = "Som-tos pel nis min mean nek tom-nae te. "
          default_instructions = ""
          default_instructions_outcome = "derm-bei pjea-yeam m-dong teat"
          custom_or_no_instructions_outcome = "Yerng neng pjeur tov nek m-dong teat nov pel mean nek tom-nae"
        when :reminder
          greeting = "Sousdey"
          greeting << " #{options[:users_name].capitalize}" if options[:users_name]
          notification = "#{greeting}! Jong rok mit tmey? "
          default_outcome = ""
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
        (notification << instructions << outcome).strip
      }
    }
  }
}
