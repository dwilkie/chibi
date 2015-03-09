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
    # eject the current cassette, and insert a new nuntium cassette with a unique token
    # then after the request, eject the cassette
    VCR.configure do |c|
      cassette_filter = lambda { |req| URI.parse(req.uri).path == nuntium_send_ao_path }
      c.before_http_request(cassette_filter) do |request|
        VCR.eject_cassette
        VCR.insert_cassette(:nuntium, :erb => nuntium_erb(options))
      end

      c.after_http_request(cassette_filter) do
        VCR.eject_cassette
      end
    end

    yield
  end

  alias_method :expect_delivery_via_nuntium, :expect_message

  def expect_delivery_via_twilio(options = {}, &block)
    VCR.use_cassette(
      :"twilio/post_messages",
      :erb => twilio_post_messages_erb(options)
    ) { yield }
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

  def assert_fetch_twilio_message_status_job_enqueued!(job, options = {})
    expect(job).to be_present
    expect(job[:args]).to eq([options[:id]])
    expect(job[:job]).to eq(TwilioMessageStatusFetcherJob)
    expect(job[:at]).to be_present
  end

  def assert_deliver(options = {})
    via = options.delete(:via)
    via ||= :nuntium if deliver_via_nuntium?
    if via == :twilio
      assert_deliver_via_twilio!(options)
    elsif via == :nuntium
      assert_deliver_via_nuntium!(options)
    else
      assert_deliver_via_smsc!(options)
    end
  end

  def assert_deliver_via_nuntium!(options = {})
    last_request = webmock_requests.last
    uri = last_request.uri
    expect(uri.path).to eq(nuntium_send_ao_path)
    last_request_data = JSON.parse(last_request.body).first
    expect(last_request_data["body"]).to eq(options[:body]) if options[:body].present?
    expect(last_request_data["to"]).to eq("sms://#{options[:to]}") if options[:to].present?
    expect(last_request_data["suggested_channel"]).to eq(options[:suggested_channel]) if options[:suggested_channel].present?
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
    job = enqueued_jobs.last
    assert_fetch_twilio_message_status_job_enqueued!(job, options)
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
        options[:body]
      ]
    )
    expect(job[:queue]).to eq(Rails.application.secrets[:smpp_internal_mt_message_queue])
  end

  def post_message(options = {})
    options[:from] = options[:from].mobile_number if options[:from].is_a?(User)
    aggregator_params = options[:via_nuntium] ? nuntium_message_params(options) : twilio_message_params(options)

    expect_locate(options) do
      expect_message do
        trigger_job do
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

  def nuntium_message_params(options = {})
    {
      :message => {
        :from => options[:from],
        :body => options[:body],
        :guid => options[:guid] || generate(:guid),
        :application => options[:application] || "chatbox",
        :channel => options[:channel] || "test",
        :to => options[:to] || "012456789",
        :subject => options[:subject] || ""
      }
    }
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
      :message_sid => "SM908e28e9909641369494f1767ba5c0dd"
    ).merge(options)
  end

  def nuntium_erb(options = {})
    {
      :url => Rails.application.secrets[:nuntium_url],
      :account => Rails.application.secrets[:nuntium_account],
      :application => Rails.application.secrets[:nuntium_application],
      :password => Rails.application.secrets[:nuntium_password],
      :token => options.delete(:token) || generate(:token),
      :to => options.delete(:to) || generate(:mobile_number),
      :body => options.delete(:body) || "hello"
    }.merge(options)
  end

  def twilio_post_messages_path(options = {})
    "/2010-04-01/Accounts/#{twilio_account_sid}/Messages.json"
  end

  def twilio_get_message_path(options = {})
    "/2010-04-01/Accounts/#{twilio_account_sid}/Messages/#{options[:message_sid]}.json"
  end

  def twilio_message_states
    {
      "queued" => {:reply_state => "queued_for_smsc_delivery", :reschedule_job => true},
      "sending" => {:reply_state => "queued_for_smsc_delivery", :reschedule_job => true},
      "sent" => { :reply_state => "delivered_by_smsc", :reschedule_job => true },
      "receiving" => {:reply_state => "queued_for_smsc_delivery", :reschedule_job => true},
      "delivered" => {:reply_state => "confirmed", :reschedule_job => false},
      "undelivered" => {:reply_state => "failed", :reschedule_job => false},
      "failed" => {:reply_state => "errored", :reschedule_job => false}
    }
  end

  def deliver_via_nuntium?
    Rails.application.secrets[:deliver_via_nuntium].to_i == 1
  end

  def nuntium_send_ao_path
    "/#{Rails.application.secrets[:nuntium_account]}/#{Rails.application.secrets[:nuntium_application]}/send_ao.json"
  end
end
