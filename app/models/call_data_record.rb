class CallDataRecord < ActiveRecord::Base
  VALID_TYPES = %w{InboundCdr OutboundCdr}

  include Communicable
  include Communicable::FromUser

  belongs_to :phone_call
  belongs_to :inbound_cdr

  validates :body, :duration, :bill_sec, :uuid, :type, :direction, :presence => true
  validates :uuid, :phone_call_id, :uniqueness => true, :allow_nil => true
  validates :type,  :inclusion => { :in => VALID_TYPES }

  attr_accessible :body

  after_initialize :set_cdr_attributes

  def typed
    valid? ? becomes(type.constantize) : self
  end

  private

  def set_cdr_attributes
    if new_record? && body.present?
      self.direction ||= variables["direction"]
      self.type ||= "#{direction}_cdr".classify
      self.uuid ||= variables["uuid"]
      self.duration ||= variables["duration"]
      self.bill_sec ||= variables["billsec"]
      self.from ||= cdr_from
    end
  end

  def cdr_from
    inbound? ? (valid_source("sip_from_user") || valid_source("sip_P_Asserted_Identity")) : valid_source("sip_to_user")
  end

  def unescaped_variable(name)
    Rack::Utils.unescape(variables[name]) if variables[name]
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
