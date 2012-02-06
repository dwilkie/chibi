class ChatHandler < MessageHandler
  def process!
    if user_wants_to_chat_with_someone_new?
      old_chat_partners_screen_id = chat_partner.screen_id

      let_chat_partner_know
      end_current_chat
      start_new_chat(old_chat_partners_screen_id)
    else
      forward_message
    end
  end

  private

  def end_current_chat
    chat.active_users.clear
    @chat = nil
    @chat_initiator = nil
    @chat_partner = nil
  end

  def chat
    @chat ||= user.active_chat
  end

  def chat_initiator
    @chat_initiator ||= chat.try(:user)
  end

  def chat_partner
    @chat_partner = ((user == chat_initiator) ? chat.friend : chat_initiator) if chat_initiator
  end

  def let_chat_partner_know
    reply I18n.t(
      "messages.chat_has_ended",
      :friends_screen_name => user.screen_id,
      :missing_profile_attributes => chat_partner.missing_profile_attributes,
      :locale => locale(chat_partner)
    ), chat_partner
  end

  def forward_message
    # prepend the user's screen id before the body and reply to the correct chat partner
    reply "#{user.screen_id}: #{body}", chat_partner
  end

  def user_wants_to_chat_with_someone_new?
    body.strip.downcase == "new"
  end
end
