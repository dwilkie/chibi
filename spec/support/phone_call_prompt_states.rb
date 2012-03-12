module PhoneCallPromptStates
  USER_INPUTS = {
    :gender => {
      :manditory => true,
      :accepts_answers_relating_to_gender => true,
      :next_state => {
        :contextual => true,
        :name => :asking_for_looking_for
      }
    },

    :looking_for => {
      :manditory => true,
      :accepts_answers_relating_to_gender => true,
      :next_state => {
        :name => :offering_menu
      }
    },

    :age => {
      :next_state => {
        :contextual => true,
        :name => :asking_for_gender
      },
      :twiml_options => {:numDigits => 2}
    }
  }

  module States
    def with_phone_call_prompts(&block)

      USER_INPUTS.each do |attribute, options|
        next_state = options[:next_state]
        call_contexts = [:_in_menu]
        call_contexts << nil if options[:manditory]
        call_contexts.each do |call_context|
          prompt_state = "asking_for_#{attribute}#{call_context}"
          next_state_name = next_state[:contextual] ? "#{next_state[:name]}#{call_context}" : next_state[:name]
          yield(attribute, call_context, "#{prompt_state}_phone_call".to_sym, prompt_state, next_state_name, options[:twiml_options])
        end
      end
    end
  end

  module GenderAnswers
    def with_gender_answers(phone_call_tag, attribute, &block)
      [:male, :female].each_with_index do |sex, index|
        yield(sex, "#{phone_call_tag}_caller_answers_#{sex}".to_sym, index) if USER_INPUTS[attribute][:accepts_answers_relating_to_gender]
      end
    end
  end
end
