class CallDataRecord < ActiveRecord::Base
  VALID_TYPES = %w{InboundCdr OutboundCdr Chibi::Twilio::InboundCdr Chibi::Twilio::OutboundCdr}

  after_initialize :set_type
  before_validation :set_cdr_attributes, :on => :create

  include Chibi::Communicable
  include Chibi::Communicable::FromUser

  belongs_to :phone_call
  belongs_to :inbound_cdr

  validates :phone_call, :body, :duration, :bill_sec, :uuid, :type, :direction, :presence => true
  validates :uuid, :uniqueness => true
  validates :phone_call_id, :uniqueness => {:scope => :type}
  validates :type,  :inclusion => { :in => VALID_TYPES }

  def typed
    VALID_TYPES.include?(type) ? type.constantize.new(:body => body) : self
  end

  private

  def set_type
    if new_record? && body.present?
      self.direction ||= variables["direction"]
      self.type ||= "#{direction}_cdr".classify
    end
  end

  def set_cdr_attributes
    if body.present?
      self.uuid ||= variables["uuid"]
      self.duration ||= variables["duration"]
      self.bill_sec ||= variables["billsec"]
      self.bridge_uuid ||= variables["bridge_uuid"]
      self.from ||= cdr_from
      self.phone_call ||= (find_related_phone_call(uuid) || find_related_phone_call(bridge_uuid))
    end
  end

  def find_related_phone_call(sid)
    PhoneCall.find_by_sid(sid)
  end

  def unescaped_variable(name)
    Rack::Utils.unescape(variables[name]).strip if variables[name]
  end

  def valid_source(name)
    normalized_value = unescaped_variable(name)
    normalized_value if normalized_value =~ /\A\+?\d+\z/
  end

  def inbound?
    direction == "inbound"
  end

  def variables
    @variables ||= MultiXml.parse(body)["cdr"]["variables"]
  end
end
