module TwilioHelpers
  private

  def asserted_number_formatted_for_twilio(number)
    "+#{number}"
  end

  def twilio_cassette_erb(options = {})
    {
      :account_sid => twilio_account_sid,
      :auth_token =>  twilio_auth_token,
      :application_sid => twilio_application_sid,
    }.merge(options)
  end

  def twilio_number(options = {})
    twilio_numbers = twilio_numbers(options)
    options[:default] == false ? twilio_numbers.last : twilio_numbers.first
  end

  def twilio_numbers(options = {})
    config_key = "twilio_outgoing_numbers"
    config_key += "_sms_capable" if options[:sms_capable]
    numbers = Rails.application.secrets[config_key].to_s.split(":")
    options[:formatted] == false ? numbers : numbers.map { |number| asserted_number_formatted_for_twilio(number) }
  end

  def twilio_account_sid
    Rails.application.secrets[:twilio_account_sid]
  end

  def twilio_auth_token
    Rails.application.secrets[:twilio_auth_token]
  end

  def twilio_application_sid
    Rails.application.secrets[:twilio_application_sid]
  end

  module TwimlAssertions
    def parse_twiml(xml)
      full_response = Nokogiri::XML(xml) do |config|
        config.options = Nokogiri::XML::ParseOptions::DEFAULT_XML | Nokogiri::XML::ParseOptions::NOBLANKS
      end

      full_response.xpath("/Response")
    end

    def assert_twiml!(raw_response, command, options = {}, &block)
      index = options.delete(:index) || 0
      content = options.delete(:content)

      twiml_response = raw_response.is_a?(String) ? parse_twiml(raw_response) : raw_response

      xpath = command_xpath(twiml_response, command)

      # asserts that each asserted attribute is present in the TwiML
      options.each do |attribute, value|
        expect(xpath[index].attributes[attribute.to_s].value).to eq(value.to_s)
      end

      # asserts that no extra attributes are present in the TwiML
      xpath[index].attributes.each do |attribute_name, attribute_value|
        expect(attribute_value.value).to eq(options[attribute_name.to_sym])
      end

      block_given? ? yield(xpath) : (expect(xpath[index].content.strip).to eq(content))
    end

    def assert_no_twiml!(raw_response, command)
      twiml_response = parse_twiml(raw_response)
      xpath = command_xpath(twiml_response, command)
      expect(xpath).to be_empty
    end

    def command_xpath(twiml_response, command)
      twiml_response.xpath("//#{command.to_s.capitalize}")
    end

    def assert_play!(raw_response, path, options = {})
      assert_twiml!(
        raw_response,
        :play,
        {:content => asserted_play_url(path)}.merge(options)
      )
    end

    def assert_redirect!(raw_response, url, options = {})
      assert_twiml!(
        raw_response,
        :redirect,
        {:content  => authenticated_url(url)}.merge(options)
      )
    end

    def assert_no_redirect!(raw_response)
      assert_no_twiml!(raw_response, :redirect)
    end

    def assert_hangup!(raw_response, options = {})
      assert_twiml!(raw_response, :hangup, {:content => ""}.merge(options))
    end

    def assert_dial!(raw_response, url, options = {}, &block)
      assert_twiml!(
        raw_response,
        :dial,
        {:action => authenticated_url(url)}.merge(options),
        &block
      )
      assert_no_redirect!(raw_response)
    end

    def assert_number!(twiml_response, number, options = {})
      assert_twiml!(twiml_response, :number, {:content => number}.merge(options))
    end

    def assert_numbers_dialed!(twiml_response, asserted_count, options = {})
      xpath = command_xpath(twiml_response, :number)
      expect(xpath.count).to eq(asserted_count)
    end

    def authenticated_url(url)
      uri = URI.parse(url)
      authentication_key = "http_basic_auth_phone_call"
      uri.user = Rails.application.secrets["#{authentication_key}_user"]
      uri.password =  Rails.application.secrets["#{authentication_key}_password"]
      uri.to_s
    end

    def asserted_ringback_tone(locale)
      "#{locale}/ringback_tone.mp3"
    end

    def asserted_play_url(path)
      "https://s3.amazonaws.com/chibimp3/#{path}"
    end

    def filename_with_extension(filename)
      "#{filename}.mp3"
    end

    module RSpec
      include ::TwilioHelpers::TwimlAssertions

      def assert_redirect!(options = {})
        super(twiml, asserted_redirect_url, {:method => "POST"}.merge(options))
      end

      def assert_play!
        super(twiml, asserted_filename)
      end

      def assert_hangup!
        super(twiml)
      end

      def assert_dial!(options = {}, &block)
        super(
          twiml,
          asserted_redirect_url,
          {
            :method => "POST",
            :ringback => asserted_play_url(asserted_ringback_tone(:kh))
          }.merge(options),
          &block
        )
      end
    end
  end
end
