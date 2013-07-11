class OutboundCdr < CallDataRecord
  MIN_CONVERSATION_TIME = 30

  before_validation :set_outbound_cdr_attributes, :on => :create

  after_create :activate_chat

  private

  def self.user_interaction?
    false
  end

  def set_outbound_cdr_attributes
    if body.present?
      self.inbound_cdr ||= InboundCdr.where(:direction => "inbound").find_by_uuid(bridge_uuid)
    end
  end

  def activate_chat
    caller = phone_call.try(:user)
    called_user = user
    chat = Chat.find_by_user_id_and_friend_id(caller.id, called_user.id) if caller
    if chat && !chat.active?
      chat.reactivate!(:force => true)
      conversation_type = bill_sec >= MIN_CONVERSATION_TIME ? :conversation : :short_conversation
      chat.replies.build(:user => caller).follow_up!(called_user, :to => :caller, :after => conversation_type)
      chat.replies.build(:user => called_user).follow_up!(caller, :to => :called_user, :after => conversation_type)
    end
  end

  def cdr_from
    valid_source("sip_to_user") || valid_source(
      "caller_profile", "destination_number", :root => "callflow"
    )
  end

  def find_related_phone_call
    PhoneCall.find_by_sid(bridge_uuid)
  end
end
