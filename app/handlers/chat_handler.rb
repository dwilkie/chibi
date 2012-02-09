class ChatHandler < MessageHandler
  def process!
    assign_message_to_chat

    if user_wants_to_chat_with_someone_new?
      start_new_chat
    elsif user_wants_to_logout?
      logout_user
    else
      forward_message
    end
  end

  private

  def assign_message_to_chat
    message.chat = active_chat
    message.save
  end

  def forward_message
    active_chat.forward_message(user, body)
  end

  def user_wants_to_chat_with_someone_new?
    body.strip.downcase == "new"
  end
end
