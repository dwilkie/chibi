module Chibi
  module Twilio
    module CallDataRecord
      include ApiHelpers
      extend ActiveSupport::Concern

      included do
        serialize :body, Hash
      end

      # this should always return a string
      def body
        write_attribute(:body, parsed_body) if read_attribute(:body).empty?
        read_attribute(:body).to_xml(:root => "cdr")
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
  end
end
