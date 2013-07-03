module Chibi
  module Twilio
    module CallDataRecord
      include ApiHelpers
      extend ActiveSupport::Concern

      included do
        serialize :body, Hash
      end

      def body
        returned_body = read_attribute(:body)
        if returned_body.empty?
          write_attribute(:body, variables)
          variables
        else
          returned_body
        end
      end

      private

      def twilio_call
        @twilio_call ||= twilio_client.account.calls.get(uuid)
      end

      def variables
        @variables ||= {
          "duration" => twilio_call.duration,
          "billsec" => twilio_call.duration,
        }
      end
    end
  end
end
