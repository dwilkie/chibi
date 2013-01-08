shared_context "existing users" do
  include MobilePhoneHelpers

  USERS = [:dave, :nok, :mara, :alex, :joy]

  USERS.each do |user|
    let(user) { create(user) }
  end

  def load_users
    USERS.each do |user|
      send(user)
    end
  end

  let(:registered_sp_users) do
    users = []
    with_service_providers do |service_provider, prefix, short_code, factory_name|
      users << User.create!(:mobile_number => build(factory_name).mobile_number)
    end
    users
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

    xpath = command_xpath(twiml_response, command)

    options.each do |attribute, value|
      xpath[index].attributes[attribute.to_s].value.should == value.to_s
    end

    block_given? ? yield(xpath) : xpath[index].content.strip.should.should == content
  end

  def assert_no_twiml(twiml_response, command)
    xpath = command_xpath(twiml_response, command)
    xpath.should be_empty
  end

  def command_xpath(twiml_response, command)
    twiml_response.xpath("//#{command.to_s.capitalize}")
  end

  def assert_play(twiml_response, path, options = {})
    assert_twiml(twiml_response, :play, options.merge(:content => "https://s3.amazonaws.com/chibimp3/#{path}"))
  end

  def assert_gather(twiml_response, options = {}, &block)
    assert_twiml(twiml_response, :gather, options, &block)
  end

  def assert_redirect(twiml_response, url, options = {})
    assert_twiml(twiml_response, :redirect, options.merge(:content => authenticated_url(url)))
  end

  def assert_no_redirect(twiml_response)
    assert_no_twiml twiml_response, :redirect
  end

  def assert_hangup(twiml_response, options = {})
    assert_twiml(twiml_response, :hangup, options.merge(:content => ""))
  end

  def assert_dial(twiml_response, url, number, options = {})
    assert_twiml(twiml_response, :dial, options.merge(:content => number, :action => authenticated_url(url)))
    assert_no_redirect(twiml_response)
  end

  def authenticated_url(uri)
    url = URI.parse(uri)
    authentication_key = "HTTP_BASIC_AUTH_PHONE_CALL"
    url.user = ENV["#{authentication_key}_USER"]
    url.password = ENV["#{authentication_key}_PASSWORD"]
    url.to_s
  end

  def filename_with_extension(filename)
    "#{filename}.mp3"
  end
end
