class CallDataRecord < ActiveRecord::Base
  VALID_TYPES = %w{InboundCdr OutboundCdr}

  belongs_to :phone_call
  belongs_to :inbound_cdr

  validates :body, :duration, :bill_sec, :uuid, :type, :direction, :presence => true
  validates :uuid, :phone_call_id, :uniqueness => true, :allow_nil => true
  validates :type,  :inclusion => { :in => VALID_TYPES }

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
    end
  end

  def variables
    @variables ||= MultiXml.parse(body)["cdr"]["variables"]
  end
end
