module Chibi
  module Twilio
    class OutboundCdr < ::OutboundCdr
      include Chibi::Twilio::CallDataRecord

      def parsed_body
        @parsed_body ||= super.deep_merge(
          "variables" => {
            "direction" => direction,
            "sip_to_user" => twilio_call.to,
            "bridge_uuid" => twilio_call.parent_call_sid
          }
        )
      end

      def direction
        twilio_call.direction =~ /outbound/ ? "outbound" : twilio_call.direction
      end
    end
  end
end
