module PhoneCallPromptStates
  module States
    def with_phone_call_prompts(&block)
      [:gender, :looking_for].each do |attribute|
        [nil, :_in_menu].each do |call_context|
          prompt_state = "asking_for_#{attribute}#{call_context}"
          yield(attribute, call_context, "#{prompt_state}_phone_call".to_sym, prompt_state)
        end
      end
    end
  end

  module GenderAnswers
    def with_gender_answers(phone_call_tag, &block)
      [:male, :female].each_with_index do |sex, index|
        yield(sex, "#{phone_call_tag}_caller_answers_#{sex}".to_sym, index)
      end
    end
  end
end
