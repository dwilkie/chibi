class CallDataRecord::Base < ActiveRecord::Base
  self.table_name = :call_data_records

  INBOUND_DIRECTION = "inbound"
  OUTBOUND_DIRECTION = "outbound"

  include Chibi::Communicable::FromUser

  belongs_to :phone_call
  belongs_to :inbound_cdr, :class_name => "CallDataRecord::Base"

  def self.inbound
    where(:direction => INBOUND_DIRECTION)
  end

  def self.outbound
    where(:direction => OUTBOUND_DIRECTION)
  end

  def inbound?
    direction == INBOUND_DIRECTION
  end

  def outbound?
    direction == OUTBOUND_DIRECTION
  end

  private

  def find_related_phone_call
    PhoneCall.find_by_sid(uuid)
  end
end
