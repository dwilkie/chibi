class CallDataRecord < ActiveRecord::Base
  belongs_to :phone_call

  validates :body, :phone_call, :duration, :bill_sec, :rfc2822_date, :uuid, :presence => true
  validates :uuid, :phone_call_id, :uniqueness => true

  before_validation(:on => :create) do
    set_attributes
  end

  private

  def set_attributes
    if body.present?
      variables = parsed_body["variables"]
      self.uuid ||= variables["uuid"]
      self.duration ||= variables["duration"]
      self.bill_sec ||= variables["billsec"]
      self.rfc2822_date ||= Rack::Utils.unescape(variables["RFC2822_DATE"])
      self.phone_call ||= PhoneCall.find_by_sid(uuid)
    end
  end

  def parsed_body
    @parsed_body ||= MultiXml.parse(body)["cdr"]
  end
end
