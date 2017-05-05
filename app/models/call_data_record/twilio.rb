class CallDataRecord::Twilio < CallDataRecord::Base
  include Chibi::Twilio::ApiHelpers

  def fetch!
    self.direction = twilio_call.direction =~ /\Aoutbound/ ? "outbound" : twilio_call.direction
    self.rfc2822_date = twilio_call.start_time
    self.duration = twilio_call.duration
    self.bill_sec = twilio_call.duration
    self.from = inbound? ? twilio_call.from : twilio_call.to
    self.bridge_uuid = twilio_call.parent_call_sid
    self.inbound_cdr ||= self.class.inbound.find_by_uuid(bridge_uuid)
    self.phone_call = find_related_phone_call if inbound?
  end

  private

  def twilio_call
    @twilio_call ||= twilio_client.account.calls.get(uuid)
  end
end
