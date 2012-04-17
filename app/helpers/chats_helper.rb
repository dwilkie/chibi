module ChatsHelper
  def chat_user_link(chat, user_type)
    user = chat.send(user_type)
    user ? link_to(user.screen_id, user_path(user)) : "-"
  end
end
