module MessagingHelpers

  def initiate_chat(user)
    load_users
    post_message(:from => user.mobile_number, :body => "")
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

  private

  def post_message(options = {})
    if options[:location]
      options[:cassette] ||= "results"
      options[:vcr_options] ||= { :erb => true }
    else
      options[:cassette] ||= "no_results"
      options[:vcr_options] ||= { :match_requests_on => [:method, VCR.request_matchers.uri_without_param(:address)] }
    end

    VCR.use_cassette(options[:cassette], options[:vcr_options]) do
      expect_message do
        with_resque do
          post messages_path,
          {
            :from => options[:from], :body => options[:body]
          },
          {'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(
            ENV["HTTP_BASIC_AUTH_USER"], ENV["HTTP_BASIC_AUTH_PASSWORD"]
          )}

          response.location.should == message_path(Message.last)
          response.status.should be(201)
        end
      end
    end
  end
end
