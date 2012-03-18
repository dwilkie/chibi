module PhoneCallHelpers
  include AuthenticationHelpers

  def make_call(options = {})
    post_phone_call options
  end

  alias :update_call_status :make_call

  private

  def post_phone_call(options = {})
    options[:call_sid] ||= build(:phone_call).sid
    post phone_calls_path(:format => :xml),
    {
      :From => options[:from],
      :CallSid => options[:call_sid],
      :Channel => options[:channel] || "test",
      :Digits => options[:digits],
      :To => options[:to]
    }, authentication_params(:phone_call)

    response.status.should be(options[:response] || 200)
    options[:call_sid]
  end

  module States
    PHONE_CALL_STATES = {
      :welcoming_user => {},
      :offering_menu => {:caller_wants_menu => "8"},
      :asking_if_user_wants_to_find_a_new_friend_or_call_existing_one => {
        :caller_wants_existing_friend => "1", :caller_wants_new_friend => "2"
      },
      :connecting_user_with_new_friend => {},
      :telling_user_to_try_again_later => {}
    }

    def with_phone_call_states(&block)
      PHONE_CALL_STATES.each do |phone_call_state, digit_sub_factories|
        yield(phone_call_state.to_s, digit_sub_factories, "#{phone_call_state}_phone_call")
      end
    end
  end

  module PromptStates
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

    module GenderAnswers
      def with_gender_answers(phone_call_tag, attribute, &block)
        [:male, :female].each_with_index do |sex, index|
          yield(sex, "#{phone_call_tag}_caller_answers_#{sex}".to_sym, index) if USER_INPUTS[attribute][:accepts_answers_relating_to_gender]
        end
      end
    end
  end
end
