module MessagingHelpers
  include AuthenticationHelpers

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
      cassette_filter = lambda { |req| URI.parse(req.uri).host == URI.parse(ENV["NUNTIUM_URL"]).host }
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
    last_request = FakeWeb.last_request
    last_request.path.should == "/#{ENV["NUNTIUM_ACCOUNT"]}/#{ENV["NUNTIUM_APPLICATION"]}/send_ao.json"
    last_request_data = JSON.parse(last_request.body).first
    last_request_data["body"].should == options[:body] if options[:body].present?
    last_request_data["to"].should == "sms://#{options[:to]}" if options[:to].present?
  end

  def expect_locate(options = {}, &block)
    if options[:location]
      options[:cassette] ||= "results"
      options[:vcr_options] ||= { :erb => true }
    else
      options[:cassette] ||= "no_results"
      options[:vcr_options] ||= { :match_requests_on => [:method, VCR.request_matchers.uri_without_param(:address)] }
    end

    VCR.use_cassette(options[:cassette], options[:vcr_options]) { yield }
  end

  def non_introducable_examples
    ["", "new"]
  end

  private

  def post_message(options = {})
    options[:from] = options[:from].mobile_number if options[:from].is_a?(User)

    expect_locate(options) do
      expect_message do
        with_resque do
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

          response.status.should be(options[:response] || 201)
        end
      end
    end
  end

  def nuntium_erb(options = {})
    {
      :url => ENV["NUNTIUM_URL"],
      :account => ENV["NUNTIUM_ACCOUNT"],
      :application => ENV["NUNTIUM_APPLICATION"],
      :password => ENV["NUNTIUM_PASSWORD"],
      :token => options.delete(:token) || generate(:token)
    }.merge(options)
  end
end
