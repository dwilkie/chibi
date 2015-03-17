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
end
