class ReadyHandler < MessageHandler

  def process!
    if contains_command?(:meet)
      message = I18n.t(
        "messages.new_match",
        :match => User.match(user),
        :name => user.name
      )
    else
      message = "text 'find' to find"
    end

    reply message
  end
end

