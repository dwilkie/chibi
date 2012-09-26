{
  :kh => {
    :replies => {
      :greeting => lambda {|key, options|

        sender = options[:friend]
        recipient = options[:recipient]

        sender_name = " #{sender.screen_id}" if sender.try(:name)
        recipient_name = " #{recipient.screen_id}" if recipient.try(:name)

        i_ams = ["nhom", "nhom", "nhum", "i am", "i'm", "m"]
        name_announcements = ["Nhom chhmous", "My name"]

        i_am = (i_ams | name_announcements).sample
        i_am_gender = i_ams.sample

        female_genders = ["girl na", "srey na", "gril na", "srey ja", "girl ja", "gril ja"]
        female_gender = female_genders.sample

        sender_intro = ""
        sender_intro << " #{i_am}#{sender_name}" if sender_name
        sender_intro << " #{i_am_gender} #{female_gender}" if sender.try(:female?)

        greetings = ["Sousdey", "Hi", "Hello"]
        greeting = greetings.sample

        greeting_punctuations = ["!", ",", "."]
        greeting_punctuation = greeting_punctuations.sample

        recipient_starter = "#{greeting}#{recipient_name}#{greeting_punctuation}"
        recipient_questions = []

        name_questions = [
          "What's ur name?", "Nek chhmous ey?", "Can you tell me ur name?"
        ]

        gender_questions = [
          "You boy or girl?", "You girl or boy?",
          "Bros ru srey?", "Srey ru bros?", "U b or g?", "You man or woman?"
        ]

        location_questions = [
          "You nov na?", "Live na?", "Where do you live?", "Come from?", "U nov na del?"
        ]

        age_questions = [
          "How old r u?", "A yu ponman heoy?", "Ayuk ponman?", "How old?"
        ]

        recipient_questions << name_questions.sample unless recipient_name.present?
        recipient_questions << gender_questions.sample unless recipient.try(:gender).present?
        recipient_questions << location_questions.sample unless recipient.try(:city).present?
        recipient_questions << age_questions.sample unless recipient.try(:age).present?

        recipient_question = " #{recipient_questions.shuffle.join(' ')}"

        introductions = [
          "#{recipient_starter}#{sender_intro} soksabay te?#{recipient_question}",
          "#{recipient_starter}#{sender_intro} nhom rikreay nas del ban skal.#{recipient_question}",
          "#{recipient_starter}#{sender_intro} nek leng sms chea moy nhom te?#{recipient_question}",
          "#{recipient_starter}#{sender_intro} nhom jorng skoul nek ban te?#{recipient_question}",
          "Oh#{sender_intro} can i make friend with you#{recipient_name}?#{recipient_question}",
          "#{recipient_starter}#{sender_intro} jong chat chea moy nhom ot?#{recipient_question}",
          "#{greeting}#{greeting_punctuation}#{sender_intro}#{recipient_name} how a u 2 day?#{recipient_question}",
          "#{recipient_starter}#{sender_intro} how a you doing now?#{recipient_question}",
          "#{recipient_starter}#{sender_intro}#{recipient_question}",
          "#{sender_intro} I want to make friend with ok te#{recipient_name}?#{recipient_question}",
          "#{recipient_starter}#{sender_intro} do ey neng fri ? H a u 2day?#{recipient_question}",
          "#{recipient_starter}#{sender_intro} m really happy 2 make friend with u.#{recipient_question}",
          "#{recipient_starter}#{sender_intro} nice to know u.#{recipient_question}"
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
