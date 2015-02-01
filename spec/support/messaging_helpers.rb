require_relative "authentication_helpers"
require_relative "location_helpers"
require_relative "active_job_helpers"
require_relative "web_mock"

module MessagingHelpers
  include AuthenticationHelpers
  include LocationHelpers
  include ActiveJobHelpers
  include WebMockHelpers

  EXAMPLES = YAML.load_file(File.join(File.dirname(__FILE__), 'message_examples.yaml'))

  def initiate_chat(user, friend = nil)
    load_users
    post_message(:from => user, :body => "")
    post_message(:from => friend, :body => "") if friend
  end

  def send_message(options = {})
    post_message options
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

  def expect_ao_fetch(options = {}, &block)
    options[:state] ||= "delivered"
    VCR.use_cassette(:nuntium_get_ao, :erb => nuntium_erb(options)) do
      yield
    end
  end

  def assert_deliver(options = {})
    options[:via] ||= :twilio unless options[:mt_message_queue]

    if options[:via] == :twilio
      # assert twilio delivery
    elsif options[:via] == :nuntium
      last_request = webmock_requests.last
      uri = last_request.uri
      expect(uri.path).to eq(nuntium_send_ao_path)
      last_request_data = JSON.parse(last_request.body).first
      expect(last_request_data["body"]).to eq(options[:body]) if options[:body].present?
      expect(last_request_data["to"]).to eq("sms://#{options[:to]}") if options[:to].present?
      expect(last_request_data["suggested_channel"]).to eq(options[:suggested_channel]) if options[:suggested_channel].present?
    else
      job = enqueued_jobs.last
      expect(job[:args]).to eq([options[:id], options[:short_code], options[:to], options[:body]])
      expect(job[:queue]).to eq(options[:mt_message_queue])
    end
  end

  def non_introducable_examples
    ["", "new"]
  end

  private

  def post_message(options = {})
    options[:from] = options[:from].mobile_number if options[:from].is_a?(User)

    expect_locate(options) do
      expect_message do
        trigger_job do
          post messages_path,
          {:message => {
            :from => options[:from],
            :body => options[:body],
            :guid => options[:guid] || generate(:guid),
            :application => options[:application] || "chatbox",
            :channel => options[:channel] || "test",
            :to => options[:to] || "012456789",
            :subject => options[:subject] || ""
          }},

          authentication_params(:message)

          expect(response.status).to be(options[:response] || 201)
        end
      end
    end
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

  def nuntium_send_ao_path
    "/#{Rails.application.secrets[:nuntium_account]}/#{Rails.application.secrets[:nuntium_application]}/send_ao.json"
  end
end
