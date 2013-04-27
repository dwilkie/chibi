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
      :Digits => options[:digits],
      :To => options[:to],
      :DialCallStatus => options[:dial_call_status].try(:to_s).try(:dasherize),
      :CallStatus => options[:call_status].try(:to_s).try(:dasherize),
      :ApiVersion => options[:api_version] || "2010-04-01"
    }
  end

  private

  def post_phone_call(options = {})
    options[:call_sid] ||= build(:phone_call).sid
    options[:from] = options[:from].mobile_number if options[:from].is_a?(User)
    options[:to] ||= twilio_number

    post phone_calls_path(:format => :xml), call_params(options), authentication_params(:phone_call)

    response.status.should be(options[:response] || 200)
    options[:call_sid]
  end

  module Twilio
    def twilio_number(options = {})
      twilio_numbers = twilio_numbers(options)
      options[:default] == false ? twilio_numbers.last : twilio_numbers.first
    end

    def twilio_numbers(options = {})
      twilio_numbers = ENV['TWILIO_OUTGOING_NUMBERS'].split(":")
      return twilio_numbers if options[:formatted] == false

      formatted_numbers = []

      twilio_numbers.each do |number|
        formatted_numbers << Phony.formatted(
          number, :format => :international, :spaces => ""
        )
      end

      formatted_numbers
    end

    def sample_adhearsion_twilio_api_version
      "adhearsion-twilio-0.0.1"
    end
  end

  module States
    def with_phone_call_states(options = {}, &block)
      options[:voice_prompts] = true unless options[:voice_prompts] == false
      state_file = "phone_call_states.yaml"
      call_type = options[:voice_prompts] ? "with_voice_prompts" : "without_voice_prompts"
      phone_call_states = YAML.load_file(File.join(File.dirname(__FILE__), state_file))[call_type]
      phone_call_states.each do |phone_call_state|
        if phone_call_state.is_a?(Hash)
          state = phone_call_state.keys.first
          state_properties = phone_call_state[state]
          if state_properties.is_a?(Hash)
            next_state = state_properties.keys.first
            state_properties = state_properties[next_state]
            substates = state_properties["substates"] || {}
            traits = state_properties["traits"] || []
            twiml_expectation = state_properties["twiml_expectation"]
          else
            next_state = state_properties
          end
        else
          state = next_state = phone_call_state
        end

        yield(state.to_sym, traits.map(&:to_sym), next_state.to_sym, twiml_expectation, substates)
      end
    end
  end
end
