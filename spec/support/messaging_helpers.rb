module MessagingHelpers
  include Rack::Test::Methods

  def send_message(options = {})
    uri = URI.parse(Nuntium.url)
    uri.path = "/#{Nuntium.account}/#{Nuntium.application}/send_ao"
    uri.user = "#{Nuntium.account}%2F#{Nuntium.application}"
    uri.password = Nuntium.password

    FakeWeb.register_uri(:post, uri.to_s, :status => ["200", "OK"])

    authorize Nuntium.incoming_user, Nuntium.incoming_password
    post mo_messages_path, {
      "subject" => "",
      "from"=>"sms://#{options[:from].mobile_number}",
      "country" => "KH",
      "guid" => "523g6e85-c5ff-45dc-b854-59e00d66c852",
      "application" => "chatbox",
      "to" => "sms://1234",
      "channel"=>"chatbox",
      "body" => options[:body]
    }
  end

  def last_reply
    mt_message_params = Rack::Utils.parse_query(FakeWeb.last_request.body)
    user = User.find_by_mobile_number(Nuntium.address(mt_message_params["to"]))
    user.mt_messages.build(mt_message_params.slice("body"))
  end
end

