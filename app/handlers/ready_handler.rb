class ReadyHandler < MessageHandler

  def process!
    if contains_command?(:meet)
      usernames = User.matches(user).map {|user| user.username }
      message = I18n.t(
        "messages.suggestions",
        :looking_for => user.looking_for,
        :usernames => usernames
      )
    else
      message = "text 'find' to find"
    end

    reply message
  end
end

