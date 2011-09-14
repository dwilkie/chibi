class RockingHandler < MessageHandler
  def process!(text)
    if text.include?("find")
      matches = User.matches(user)
      reply I18.t(
        "messages.suggestions",
        :looking_for => user.looking_for)
        :usernames => matches
         "nhom skual #{matches.size} nak: #{matches.join(', ')}"
    end
  end
end

