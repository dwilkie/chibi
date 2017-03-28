class Chibi::Twilio::InboundCdr < InboundCdr
  include Chibi::Twilio::CallDataRecord

  # this is needed to correctly accociate Chibi::Twilio::OutboundCdr
  has_many :outbound_cdrs, :class_name => "Chibi::Twilio::OutboundCdr"

  def fetch!
    self.direction = twilio_call.direction
    self.rfc2822_date = twilio_call.start_time
    self.duration = twilio_call.duration
    self.bill_sec = twilio_call.duration
    self.from = twilio_call.from
    self.phone_call = find_related_phone_call
  end

  private

  def set_type
  end

  def set_inbound_cdr_attributes
  end
end
