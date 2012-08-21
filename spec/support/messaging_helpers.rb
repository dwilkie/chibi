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

  def expect_message(&block)
    VCR.use_cassette(
      "nuntium",
      :erb => {
        :url => ENV["NUNTIUM_URL"],
        :account => ENV["NUNTIUM_ACCOUNT"],
        :application => ENV["NUNTIUM_APPLICATION"],
        :password => ENV["NUNTIUM_PASSWORD"]
      },
      :allow_playback_repeats => true
    ) { yield }
  end

  def assert_deliver(body)
    last_request = FakeWeb.last_request
    last_request.path.should == "/#{ENV["NUNTIUM_ACCOUNT"]}/#{ENV["NUNTIUM_APPLICATION"]}/send_ao.json"
    JSON.parse(last_request.body).first["body"].should == body
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
end
