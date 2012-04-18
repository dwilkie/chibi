require File.join(File.dirname(__FILE__), 'authentication_helpers')

module PhoneCallHelpers
  include AuthenticationHelpers

  def make_call(options = {})
    post_phone_call options
  end

  alias :update_call_status :make_call

  def call_params(options = {})
    {
      :From => options[:from],
      :CallSid => options[:call_sid],
      :Channel => options[:channel] || "test",
      :Digits => options[:digits],
      :To => options[:to],
      :DialCallStatus => options[:dial_call_status].try(:to_s).try(:dasherize),
      :CallStatus => options[:call_status].try(:to_s).try(:dasherize)
    }
  end

  private

  def post_phone_call(options = {})
    options[:call_sid] ||= build(:phone_call).sid
    options[:from] = options[:from].mobile_number if options[:from].is_a?(User)

    post phone_calls_path(:format => :xml), call_params(options), authentication_params(:phone_call)

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
    PHONE_CALL_STATES = YAML.load_file(File.join(File.dirname(__FILE__), 'phone_call_states.yaml'))

    def with_phone_call_states(&block)
      PHONE_CALL_STATES.each do |phone_call_state|
        if phone_call_state.is_a?(Hash)
          state = phone_call_state.keys.first
          state_properties = phone_call_state[state]
          if state_properties.is_a?(Hash)
            next_state = state_properties.keys.first
            state_properties = state_properties[next_state]
            manditory = state_properties["manditory"]
            contextual_substate_next_states = state_properties["contextual_substate_next_states"]
            substates = state_properties["substates"]
            parent = state_properties["parent"]
            twiml_expectation = state_properties["twiml_expectation"]
          else
            next_state = state_properties
          end
        else
          state = next_state = phone_call_state
        end

        substates ||= {}
        state_contexts = manditory ? [nil, :_in_menu] : [nil]

        state_contexts.each do |state_context|
          contextual_state = "#{state}#{state_context}"
          contextual_next_state = "#{next_state}#{state_context}"
          base_factory_name = "#{contextual_state}_phone_call".to_sym
          substate_attribute_values = {}

          substates.each do |substate_method, substate_examples|

            substate_examples.each do |substate_key, next_state_and_value|

              if next_state_and_value.is_a?(Hash)
                substate_expectations = next_state_and_value["expectations"]

                if next_state_and_value["parent"]
                  substate_parent = true
                  substate_next_state = substate_key
                  substate_suffix = substate_method
                else
                  substate_next_state_without_context = next_state_and_value.keys.first
                  if contextual_substate_next_states
                    substate_next_state = "#{substate_next_state_without_context}#{state_context}"
                  else
                    substate_next_state = substate_next_state_without_context
                  end

                  substate_value = next_state_and_value[substate_next_state_without_context]
                  substate_suffix = substate_key
                end
              else
                substate_next_state = substate_key
                substate_value = next_state_and_value
                substate_suffix = "#{substate_method}_#{next_state_and_value}"
              end

              if substate_parent
                attribute_values = next_state_and_value
              else
                attribute_values = {substate_method => [substate_value].flatten}
              end

              next_state_attributes = {"factory" => attribute_values}
              next_state_attributes.merge!("expectations" => substate_expectations) if substate_expectations

              substate_name = "#{base_factory_name}_#{substate_suffix}"
              substate_attribute_values[substate_name] = {substate_next_state.to_s => next_state_attributes}
            end
          end

          yield(base_factory_name, twiml_expectation, contextual_state, contextual_next_state, substate_attribute_values, parent)
        end
      end
    end
  end
end
