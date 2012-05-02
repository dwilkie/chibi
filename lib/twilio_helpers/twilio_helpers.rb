module TwilioHelpers
  private

  def twilio_formatted(number)
    Phony.formatted(number, :format => :international, :spaces => "")
  end

  def twilio_outgoing_number(options = {})
    twilio_numbers = twilio_outgoing_numbers(options)
    default_number = twilio_numbers.first
    alternate_number = twilio_numbers.last

    if options[:default] == false
      alternate_number
    elsif split_number = options[:for]
      split_number[0] == twilio_country_code(:default => false) ? alternate_number : default_number
    else
      default_number
    end
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

  def twilio_country_code(options = {})
    Phony.split(twilio_outgoing_number(options.merge(:formatted => false)))[0]
  end
end
