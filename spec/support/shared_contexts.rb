shared_context "existing users" do
  USERS = [:dave, :nok, :mara, :alex, :joy]

  USERS.each do |user|
    let(user) { create(user) }
  end

  def load_users
    USERS.each do |user|
      send(user)
    end
  end
end

shared_context "replies" do
  let(:replies) { Reply.all }

  def replies_to(reference_user, reference_chat = nil)
    scope = Reply.where(:to => reference_user.mobile_number)
    scope = scope.where(:chat_id => reference_chat.id) if reference_chat
    scope
  end

  def reply_to(reference_user, reference_chat = nil)
    replies_to(reference_user, reference_chat).last
  end
end

shared_context "twiml" do
  def parse_twiml(xml)
    full_response = Nokogiri::XML(xml) do |config|
      config.options = Nokogiri::XML::ParseOptions::DEFAULT_XML | Nokogiri::XML::ParseOptions::NOBLANKS
    end

    full_response.xpath("/Response")
  end

  def assert_twiml(twiml_response, command, options = {}, &block)
    index = options.delete(:index) || 0
    content = options.delete(:content)

    command_xpath = twiml_response.xpath(
      "//#{command.to_s.capitalize}"
    )

    options.each do |attribute, value|
      command_xpath[index].attributes[attribute.to_s].value.should == value.to_s
    end

    block_given? ? yield(command_xpath) : command_xpath[index].content.strip.should.should == content
  end

  def assert_play(twiml_response, path, options = {})
    assert_twiml(twiml_response, :play, options.merge(:content => "https://s3.amazonaws.com/chibimp3/#{path}"))
  end

  def assert_gather(twiml_response, options = {}, &block)
    assert_twiml(twiml_response, :gather, options, &block)
  end

  def assert_redirect(twiml_response, url, options = {})
    assert_twiml(twiml_response, :redirect, options.merge(:content => url))
  end

  def assert_dial(twiml_response, number, options = {})
    assert_twiml(twiml_response, :dial, options.merge(:content => number))
  end
end
