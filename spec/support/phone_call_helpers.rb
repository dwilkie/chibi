require_relative 'authentication_helpers'
require_relative 'twilio_helpers'

module PhoneCallHelpers
  include AuthenticationHelpers

  def make_call(options = {})
    post_phone_call(options)
  end

  def update_phone_call(phone_call, options = {})
    post_update_phone_call(phone_call, options)
  end

  def complete_call(options = {})
    post_call_status_callback(options)
  end

  def sample_call_params(options = {})
    {
      "From" => options[:from],
      "CallSid" => options[:call_sid],
      "Digits" => options[:digits],
      "CallDuration" => options[:call_duration],
      "To" => options[:to],
      "DialCallStatus" => options[:dial_call_status].try(:to_s).try(:dasherize),
      "DialCallSid" => options[:dial_call_sid],
      "CallStatus" => options[:call_status].try(:to_s).try(:dasherize),
      "ApiVersion" => options[:api_version] || sample_twilio_api_version
    }
  end

  def sample_call_status_callback_params(options = {})
    sample_call_params(options).merge(
      "CallDuration" => options[:call_duration] || 45
    )
  end

  def sample_adhearsion_twilio_api_version
    "adhearsion-twilio-0.0.1"
  end

  def sample_twilio_api_version
    "2010-04-01"
  end

  private

  def get_phone_call(phone_call, options = {})
    get(
      phone_call_path(phone_call),
      options,
      authentication_params(:phone_call)
    )
  end

  def post_phone_call(options = {})
    options[:call_sid] ||= attributes_for(:phone_call)[:sid]
    options[:from] = options[:from].mobile_number if options[:from].is_a?(User)
    options[:to] ||= twilio_number

    post(
      phone_calls_path(:format => :xml),
      sample_call_params(options),
      authentication_params(:phone_call)
    )

    assert_phone_call_response!(options)
  end

  def post_update_phone_call(phone_call, options = {})
    post(
      phone_call_path(phone_call, :format => :xml),
      sample_call_params(options),
      authentication_params(:phone_call)
    )

    assert_phone_call_response!(options)
  end

  def assert_phone_call_response!(options)
    expect(response.status).to be(options[:response] || 200)
    options[:call_sid]
  end

  def post_call_status_callback(options = {})
    post(
      phone_call_completions_path(:format => :xml),
      sample_call_status_callback_params(options),
      authentication_params(:phone_call)
    )
  end
end
