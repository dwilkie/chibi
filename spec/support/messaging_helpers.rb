module MessagingHelpers

  def initiate_chat(user)
    load_users
    post_message(:from => user.mobile_number, :body => "")
  end

  def send_message(options = {})
    post_message options
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
      post messages_path,
      {:from => options[:from], :body => options[:body]},
      {'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(
        ENV["CHAT_BOX_USERNAME"], ENV["CHAT_BOX_PASSWORD"]
      )}
    end
  end
end
