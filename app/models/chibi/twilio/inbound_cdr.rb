module Chibi
  module Twilio
    class InboundCdr < ::InboundCdr
      include Chibi::Twilio::CallDataRecord

      private

      def variables
        @variables ||= super.merge(
          "direction" => twilio_call.direction,
          "sip_from_user" => twilio_call.from,
          "RFC2822_DATE" => twilio_call.start_time
        )
      end
    end
  end
end
