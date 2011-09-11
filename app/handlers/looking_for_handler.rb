class LookingForHandler
  def process!(text, user)
    user.looking_for = text
    user.update_status :rocking
    matches = user.start_match
    user.save
    [:to => user.phone_number, :body => "nhom skual #{matches.size} nak: #{matches.join(', ')}"]
  end
end
