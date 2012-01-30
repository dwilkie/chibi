class ChatHandler < MessageHandler
  def process!
    # get the sender's active chat
    chat = user.active_chat

    # get the user who initated this chat
    chat_initiator = chat.user

    # if the sender is the chat initiator, then reply to the chat friend otherwise reply to the chat initiator
    reply_to = (user == chat_initiator) ? chat.friend : chat_initiator

    # prepend the user's screen id before the body and reply to the correct chat partner
    reply "#{user.screen_id}: #{body}", reply_to
  end
end
