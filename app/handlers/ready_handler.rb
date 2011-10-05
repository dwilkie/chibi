class ReadyHandler < MessageHandler

  def process!
    message = I18n.t(
      "messages.new_match",
      :match => User.match(user),
      :name => user.name
    )

    reply message
  end
end

