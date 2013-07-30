class CallDataRecord < ActiveRecord::Base
  VALID_TYPES = %w{InboundCdr OutboundCdr Chibi::Twilio::InboundCdr Chibi::Twilio::OutboundCdr}

  after_initialize :set_type
  before_validation :set_cdr_attributes, :on => :create

  include Chibi::Communicable
  include Chibi::Communicable::FromUser

  belongs_to :phone_call
  belongs_to :inbound_cdr

  validates :body, :duration, :bill_sec, :uuid, :type, :direction, :presence => true
  validates :uuid, :uniqueness => true
  validates :phone_call_id, :uniqueness => {:scope => :type}, :allow_nil => true
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
      self.phone_call ||= find_related_phone_call
    end
  end

  def unescaped_variable(*keys)
    options = keys.extract_options!
    raw_value = keys.unshift(options[:root] || "variables").inject(parsed_body) {|acc, e| acc[e] if acc.is_a?(Hash)}
    Rack::Utils.unescape(raw_value).strip if raw_value
  end

  def valid_source(*keys)
    normalized_value = unescaped_variable(*keys)
    normalized_value if normalized_value =~ /\A\+?\d+\z/
  end

  def variables
    parsed_body["variables"]
  end

  def parsed_body
    @parsed_body ||= MultiXml.parse(body)["cdr"]
  end
end
