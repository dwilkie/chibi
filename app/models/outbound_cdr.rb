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
    caller = phone_call && phone_call.user
    called_user = user
    chat = Chat.find_by_user_id_and_friend_id(caller.id, called_user.id) if caller
    if chat && !chat.active?
      chat.reactivate!
      conversation_type = bill_sec >= MIN_CONVERSATION_TIME ? :conversation : :short_conversation
      chat.replies.build(:user => caller).follow_up!(called_user, :to => :caller, :after => conversation_type)
      chat.replies.build(:user => called_user).follow_up!(caller, :to => :called_user, :after => conversation_type)
    end
  end

  def cdr_from
    sip_to_user.gsub(/^#{dial_string_number_prefix}/, "") if sip_to_user
  end

  def find_related_phone_call
    PhoneCall.find_by_sid(bridge_uuid)
  end

  def sip_to_user
    @sip_to_user ||= (valid_source("sip_to_user") || valid_source("caller_profile", "destination_number", :root => "callflow"))
  end

  def sip_to_host
    @sip_to_host ||= (valid_host("sip_to_host") || valid_host("caller_profile", "network_addr", :root => "callflow"))
  end

  def valid_host(*keys)
    normalized_value = unescaped_variable(*keys)
    normalized_value if normalized_value =~ /\b(?:\d{1,3}\.){3}\d{1,3}\b/
  end

  def dial_string_number_prefix
    return @dial_string_number_prefix if @dial_string_number_prefix
    if sip_to_host
      Torasup::Operator.registered.each do |country_id, operators|
        operators.each do |operator_id, operator_data|
          if operator_data["voip_gateway_host"] == sip_to_host
            @dial_string_number_prefix = operator_data["dial_string_number_prefix"]
            break
          end
        end
      end
      @dial_string_number_prefix
    end
  end
end
