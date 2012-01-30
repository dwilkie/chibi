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
    post messages_path,
    {:from => options[:from], :body => options[:body]},
    {'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(
      ENV["CHAT_BOX_USERNAME"], ENV["CHAT_BOX_PASSWORD"]
    )}
  end
end
