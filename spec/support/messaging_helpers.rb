require_relative "authentication_helpers"
require_relative "location_helpers"
require_relative "active_job_helpers"
require_relative "web_mock"

module MessagingHelpers
  include AuthenticationHelpers
  include LocationHelpers
  include ActiveJobHelpers
  include WebMockHelpers
  include TwilioHelpers

  EXAMPLES = YAML.load_file(File.join(File.dirname(__FILE__), 'message_examples.yaml'))

  private

  def initiate_chat(user, friend = nil)
    load_users
    post_message(:from => user, :body => "")
    post_message(:from => friend, :body => "") if friend
  end

  def send_message(options = {})
    post_message(options)
  end

  def expect_message(options = {}, &block)
    # eject the current cassette, and insert a new twilio cassette with a unique token
    # then after the request, eject the cassette
    VCR.configure do |c|
      cassette_filter = lambda { |req| URI.parse(req.uri).path == twilio_post_messages_path(options) }
      c.before_http_request(cassette_filter) do |request|
        VCR.eject_cassette
        VCR.insert_cassette(twilio_post_messages_cassette, :erb => twilio_post_messages_erb(options))
      end

      c.after_http_request(cassette_filter) do
        VCR.eject_cassette
      end
    end

    yield
  end

  alias_method :expect_delivery_via_twilio, :expect_message

  def twilio_post_messages_cassette
    :"twilio/post_messages"
  end

  def expect_twilio_message_status_fetch(options = {}, &block)
    VCR.use_cassette(
      :"twilio/get_message",
      :erb => twilio_get_message_erb(options)
    ) { yield }
  end

  def assert_twilio_message_status_fetched!(options = {})
    last_request = webmock_requests.last
    uri = last_request.uri
    expect(uri.path).to eq(twilio_get_message_path(options))
  end

  def assert_twilio_job!(job, options = {})
    expect(job).to be_present
    expect(job[:args]).to eq([options[:id]]) if options[:id]
    expect(job[:job]).to eq(options[:job_class])
    if options[:scheduled]
      expect(job[:at]).to be_present
    else
      expect(job[:at]).not_to be_present
    end
  end

  def assert_fetch_twilio_message_status_job_enqueued!(job, options = {})
    assert_twilio_job!(job, {:job_class => TwilioMessageStatusFetcherJob, :scheduled => true}.merge(options))
  end

  def assert_twilio_mt_message_received_job_enqueued!(job, options = {})
    assert_twilio_job!(job, {:job_class => TwilioMtMessageReceivedJob, :scheduled => false}.merge(options))
  end

  def assert_deliver(options = {})
    via = options.delete(:via) || :twilio
    via == :twilio ? assert_deliver_via_twilio!(options) : assert_deliver_via_smsc!(options)
  end

  def assert_deliver_via_twilio!(options = {})
    last_request = webmock_requests.last
    uri = last_request.uri
    expect(uri.path).to eq(twilio_post_messages_path)
    last_request_data = Rack::Utils.parse_query(last_request.body)
    expect(last_request_data["To"]).to eq(asserted_number_formatted_for_twilio(options[:to]))
    asserted_from = twilio_number(:sms_capable => true)
    expect(last_request_data["From"]).to eq(asserted_from)
    expect(last_request_data["Body"]).to eq(options[:body])
    assert_twilio_mt_message_received_job_enqueued!(enqueued_jobs[-2], options)
    assert_fetch_twilio_message_status_job_enqueued!(enqueued_jobs[-1], options)
  end

  def assert_deliver_via_smsc!(options = {})
    job = enqueued_jobs.last
    expect(job).to be_present
    expect(job[:args]).to eq(
      [
        options[:id],
        options[:smpp_server_id],
        options[:short_code],
        options[:to],
        options[:body],
        options[:smsc_priority].to_i
      ]
    )
    expect(job[:queue]).to eq(Rails.application.secrets[:smpp_internal_mt_message_queue])
  end

  def post_message(options = {})
    options[:from] = options[:from].mobile_number if options[:from].is_a?(User)
    aggregator_params = twilio_message_params(options)

    expect_locate(options) do
      expect_message do
        trigger_job(:only => [MessageProcessorJob]) do
          post(
            messages_path,
            aggregator_params,
            authentication_params(:message)
          )

          expect(response.status).to be(options[:response] || 201)
        end
      end
    end
  end

  def twilio_message_params(options = {})
    guid = options[:guid] || generate(:guid)
    {
      "ToCountry"=>"US",
      "ToState"=>"CA",
      "SmsMessageSid"=> guid,
      "NumMedia"=>"0",
      "ToCity"=>"SAN FRANCISCO",
      "FromZip"=>"",
      "SmsSid"=>guid,
      "FromState"=>"",
      "SmsStatus"=>"received",
      "FromCity"=>"",
      "Body"=>options[:body],
      "FromCountry"=>"KH",
      "To"=> options[:to] || "+14156926280",
      "ToZip"=>"94105",
      "MessageSid"=>guid,
      "AccountSid"=>Rails.application.secrets[:twilio_account_sid],
      "From"=> options[:from],
      "ApiVersion"=>"2010-04-01"
    }
  end

  def twilio_get_message_erb(options = {})
    twilio_message_erb(options).merge(
      :status => "delivered",
      :path => twilio_get_message_path(twilio_message_erb(options))
    ).merge(options)
  end

  def twilio_post_messages_erb(options = {})
    twilio_message_erb(options).merge(
      :path => twilio_post_messages_path(twilio_message_erb(options))
    ).merge(options)
  end

  def twilio_message_erb(options = {})
    twilio_cassette_erb(options).merge(
      :message_sid => generate(:twilio_sid)
    ).merge(options)
  end

  def twilio_post_messages_path(options = {})
    "/2010-04-01/Accounts/#{twilio_account_sid}/Messages.json"
  end

  def twilio_get_message_path(options = {})
    "/2010-04-01/Accounts/#{twilio_account_sid}/Messages/#{options[:message_sid]}.json"
  end

  def twilio_message_states
    {
      "queued" => {:reply_state => "delivered_by_smsc", :reschedule_job => true},
      "sending" => {:reply_state => "delivered_by_smsc", :reschedule_job => true},
      "sent" => { :reply_state => "unknown", :reschedule_job => false},
      "receiving" => {:reply_state => "delivered_by_smsc", :reschedule_job => true},
      "delivered" => {:reply_state => "confirmed", :reschedule_job => false},
      "undelivered" => {:reply_state => "failed", :reschedule_job => false},
      "failed" => {:reply_state => "errored", :reschedule_job => false}
    }
  end

  def smsc_message_states
    {
      "ENROUTE"        => {:reply_state => "delivered_by_smsc"},
      "DELIVERED"      => {:reply_state => "confirmed"},
      "EXPIRED"        => {:reply_state => "expired"},
      "DELETED"        => {:reply_state => "errored"},
      "UNDELIVERABLE"  => {:reply_state => "failed"},
      "ACCEPTED"       => {:reply_state => "delivered_by_smsc"},
      "UNKNOWN"        => {:reply_state => "unknown"},
      "REJECTED"       => {:reply_state => "failed"},
      "INVALID"        => {:reply_state => "errored"}
    }
  end
end
