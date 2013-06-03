module TwilioHelpers
  private

  def twilio_formatted(number)
    Phony.formatted(number, :format => :international, :spaces => "")
  end

  def twilio_outgoing_number(options = {})
    twilio_numbers = twilio_outgoing_numbers(options)
    options[:default] == false ? twilio_numbers.last : twilio_numbers.first
  end

  def twilio_outgoing_numbers(options = {})
    twilio_numbers = ENV['TWILIO_OUTGOING_NUMBERS'].split(":")
    return twilio_numbers if options[:formatted] == false

    formatted_numbers = []

    twilio_numbers.each do |number|
      formatted_numbers << Phony.formatted(
        number, :format => :international, :spaces => ""
      )
    end

    formatted_numbers
  end

  def twilio_number?(number)
    twilio_outgoing_numbers.include?(number)
  end

  def adhearsion_twilio_requested?(api_version)
    api_version =~ /adhearsion-twilio/
  end

  def default_pbx_dial_string(interpolations = {})
    dial_string = ENV['DEFAULT_PBX_DIAL_STRING'].dup
    interpolations.each do |interpolation, value|
      dial_string.gsub!("%{#{interpolation}}", value)
    end
    dial_string
  end
end
