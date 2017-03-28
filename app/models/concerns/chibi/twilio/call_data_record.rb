module Chibi::Twilio::CallDataRecord
  extend ActiveSupport::Concern
  include Chibi::Twilio::ApiHelpers

  # this should always return a string
  def body
    (super || parsed_body.to_xml(:root => "cdr")) if new_record?
  end

  private

  def twilio_call
    @twilio_call ||= twilio_client.account.calls.get(uuid)
  end

  def parsed_body
    @parsed_body ||= {
      "variables" => {
        "duration" => twilio_call.duration,
        "billsec" => twilio_call.duration
      }
    }
  end
end

