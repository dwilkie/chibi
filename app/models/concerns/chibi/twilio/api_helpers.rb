module Chibi
  module Twilio
    module ApiHelpers
      private

      def twilio_client
        @client ||= ::Twilio::REST::Client.new(
          Rails.application.secrets[:twilio_account_sid],
          Rails.application.secrets[:twilio_auth_token]
        )
      end

      def format_token(token)
        token.to_s.gsub(/^sm/, "SM")
      end

      def twilio_formatted(number)
        "+" + Phony.normalize(number)
      end

      def twilio_outgoing_number(options = {})
        twilio_numbers = twilio_outgoing_numbers(options)
        options[:default] == false ? twilio_numbers.last : twilio_numbers.first
      end

      def twilio_outgoing_numbers(options = {})
        config_key = "twilio_outgoing_numbers"
        config_key += "_sms_capable" if options[:sms_capable]
        twilio_numbers = Rails.application.secrets[config_key].to_s.split(":")
        options[:formatted] == false ? twilio_numbers : twilio_numbers.map { |number| twilio_formatted(number) }
      end

      def twilio_number?(number, options = {})
        twilio_outgoing_numbers(options).include?(number)
      end

      def adhearsion_twilio_requested?(api_version)
        api_version =~ /adhearsion-twilio/
      end

      def default_pbx_dial_string(interpolations = {})
        dial_string = Rails.application.secrets[:default_pbx_dial_string].dup
        interpolations.each do |interpolation, value|
          dial_string.gsub!("%{#{interpolation}}", value)
        end
        dial_string
      end
    end
  end
end
