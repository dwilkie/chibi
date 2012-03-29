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
      :To => options[:to],
      :DialCallStatus => options[:dial_call_status].try(:to_s).try(:dasherize)
    }, authentication_params(:phone_call)

    response.status.should be(options[:response] || 200)
    options[:call_sid]
  end

  module Twilio
    def formatted_twilio_number
      Phony.formatted(
        ENV['TWILIO_OUTGOING_NUMBER'], :format => :international, :spaces => ""
      )
    end
  end

  module States
    PHONE_CALL_STATES = [
      {:answered => :welcoming_user},
      {:welcoming_user => :asking_for_gender},
      {:asking_for_gender => {:asking_for_gender => {
        :state_contexts => [nil, :_in_menu],
        :substates => {:digits => {
          :caller_answers_male => {:asking_for_looking_for => "1"},
          :caller_answers_female => {:asking_for_looking_for => "2"}
        }}
      }}},
      {:asking_for_looking_for => {:asking_for_looking_for => {
        :state_contexts => [nil, :_in_menu],
        :substates => {:digits => {
          :caller_answers_male => {:offering_menu => "1"},
          :caller_answers_female => {:offering_menu => "2"}
        }}
      }}},
      :asking_for_age_in_menu,
      {:offering_menu => {:finding_new_friend => {
        :substates => {:digits => {
          :caller_wants_menu => {:offer_menu => "8"}
        }}
      }}},
      {:asking_if_user_wants_to_find_a_new_friend_or_call_existing_one => {
        :telling_user_their_friend_is_unavailable => {
        :substates => {:digits => {
          :caller_wants_existing_friend => {
            :connecting_user_with_existing_friend => "1"
          },
          :caller_wants_new_friend => {
            :connecting_user_with_new_friend => "2"
          }
        }}
      }}},
      {:finding_new_friend => :telling_user_to_try_again_later},
      {:connecting_user_with_new_friend => {
        :connecting_user_with_new_friend => {
          :substates => {:dial_status => {
            :completed => :completed
          }},
          :parent => :finding_new_friend_friend_found
        }
      }},
      {:telling_user_to_try_again_later => :hanging_up},
      :connecting_user_with_existing_friend,
      {:telling_user_their_friend_is_unavailable => :connecting_user_with_new_friend},
      :hanging_up,
      :completed
    ]

    def with_phone_call_states(&block)
      PHONE_CALL_STATES.each do |phone_call_state|
        if phone_call_state.is_a?(Hash)
          state = phone_call_state.keys.first
          state_properties = phone_call_state[state]
          if state_properties.is_a?(Hash)
            next_state = state_properties.keys.first
            state_properties = state_properties[next_state]
            state_contexts = state_properties[:state_contexts]
            substates = state_properties[:substates]
            parent = state_properties[:parent]
          else
            next_state = state_properties
          end
        else
          state = next_state = phone_call_state
        end

        substates ||= {}
        state_contexts ||= [nil]

        state_contexts.each do |state_context|
          contextual_state = "#{state}#{state_context}"
          contextual_next_state = "#{next_state}#{state_context}"
          base_factory_name = "#{contextual_state}_phone_call".to_sym
          substate_attribute_values = {}

          substates.each do |substate_method, substate_examples|
            substate_examples.each do |substate_key, next_state_and_value|

              if next_state_and_value.is_a?(Hash)
                substate_next_state = next_state_and_value.keys.first
                substate_value = next_state_and_value[substate_next_state]
                substate_suffix = substate_key
              else
                substate_next_state = next_state_and_value
                substate_suffix = "#{substate_method}_#{substate_key}"
              end

              attribute_values = {substate_method => (substate_value || substate_key)}
              substate_name = "#{base_factory_name}_#{substate_suffix}"
              substate_attribute_values[substate_name] = {substate_next_state.to_s => attribute_values}
            end
          end

          yield(base_factory_name, contextual_state, contextual_next_state, substate_attribute_values, parent)
        end
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
