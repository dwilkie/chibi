class TwilioClient
  attr_accessor :account_sid, :auth_token

  def initialize(options = {})
    self.account_sid = options[:account_sid] || ENV["TWILIO_ACCOUNT_SID"]
    self.auth_token = options[:auth_token] || ENV["TWILIO_AUTH_TOKEN"]
  end

  def fetch_call(call_sid)
    client.account.calls.get(call_sid)
  end

  def fetch_message(message_id)
    client.account.messages.get(format_message_id(message_id))
  end

  private

  def format_message_id(message_id)
    message_id.to_s.gsub(/^sm/, "SM")
  end

  def client
    @client ||= ::Twilio::REST::Client.new(account_sid, auth_token)
  end
end
