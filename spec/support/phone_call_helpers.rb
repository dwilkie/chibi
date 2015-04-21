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

  module TwilioHelpers
    include ::TwilioHelpers

    shared_examples_for "a Chibi Twilio CDR" do
      describe "#body" do
        let(:uuid) { generate(:guid) }
        subject { klass.new(:uuid => uuid) }

        it "should fetch the body from the Twilio API" do
          expect_twilio_cdr_fetch(:call_sid => uuid, :direction => direction) { subject.body }
          parsed_body = MultiXml.parse(subject.body)["cdr"]
          expect(parsed_body["variables"]["duration"]).to be_present
          expect(parsed_body["variables"]["billsec"]).to be_present
          assertions.each do |assertion_key, assertion_value|
            actual_value = parsed_body["variables"][assertion_key]
            if assertion_value == true
              expect(actual_value).to be_present
            else
              expect(actual_value).to eq(assertion_value)
            end
          end
        end
      end
    end

    private

    def expect_twilio_cdr_fetch(options = {}, &block)
      cassette = options.delete(:cassette) || "get_call"
      options[:direction] ||= "inbound"
      options[:direction] = "outbound-dial" if options[:direction] == :outbound
      options[:duration] ||= 20
      options[:from] ||= generate(:mobile_number)
      options[:to] ||= generate(:mobile_number)
      options[:call_sid] ||= generate(:guid)
      options[:parent_call_sid] ||= generate(:guid)
      VCR.use_cassette("twilio/#{cassette}", :erb => twilio_cassette_erb(options)) { yield }
    end
  end
end
