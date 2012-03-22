module TwilioHelpers

  private

  def twilio_formatted(number)
    Phony.formatted(number, :format => :international, :spaces => "")
  end

  def twilio_outgoing_number
    twilio_formatted(ENV['TWILIO_OUTGOING_NUMBER'])
  end

end
