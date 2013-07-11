module Chibi
  module Twilio
    class InboundCdr < ::InboundCdr
      include Chibi::Twilio::CallDataRecord

      # this is needed to correctly accociate Chibi::Twilio::OutboundCdr
      has_many :outbound_cdrs

      private

      def parsed_body
        @parsed_body ||= super.deep_merge(
          "variables" => {
            "direction" => twilio_call.direction,
            "sip_from_user" => twilio_call.from,
            "RFC2822_DATE" => twilio_call.start_time
          }
        )
      end
    end
  end
end
