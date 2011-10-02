module MessagingHelpers
  attr_accessor :account

  def account
    @account ||= create :account
  end

  def search(user)
    post_message(:from => user.mobile_number, :body => MessageHandler.commands[:meet].first)
  end

  def send_message(options = {})
    post_message options
  end

  def last_reply
  end

  private

  def post_message(options = {})
    post messages_path,
    {:from => options[:from], :body => options[:body]},
    {'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(
      account.username, "foobar"
    )}
  end
end

