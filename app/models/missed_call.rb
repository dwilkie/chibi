class MissedCall < ActiveRecord::Base
  include Chibi::Communicable
  include Chibi::Communicable::FromUser
  include Chibi::Twilio::ApiHelpers

  attr_accessor :subject
  attr_accessible :subject, :plain

  alias_attribute :plain, :subject

  def subject=(value)
    @subject = value

    raw_phone_number = subject.try(:match, /\d+/).try(:[], 0)
    return unless raw_phone_number

    phone_number_parts = Phony.split(raw_phone_number)
    phone_number_parts[0] = default_country_code if phone_number_parts[0] == "0"
    self.from = phone_number_parts.join
  end

  def return_call!
    twilio_client.account.calls.create(
      :from => twilio_outgoing_number,
      :to => twilio_formatted(from),
      :application_sid => ENV['TWILIO_APPLICATION_SID']
    )
  end

  private

  def default_country_code
    ENV['MISSED_CALL_COUNTRY_CODE']
  end
end
