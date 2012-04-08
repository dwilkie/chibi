module ChatsHelper
  def chatable_link(chat, chatable_resources_name)
    chatable_resource_count = chat.send("#{chatable_resources_name}_count").to_i
    chatable_resource_count.zero? ? chatable_resource_count : link_to(chatable_resource_count, send("chat_#{chatable_resources_name}_path", chat))
  end

  def chat_user_link(chat, user_type)
    user = chat.send(user_type)
    user ? link_to(user.screen_id, user_path(user)) : "-"
  end
end
