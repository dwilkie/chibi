class RegisteringHandler
  def process!(text, user)
    user.profile_details = text
    user.update_status :ready
    user.save
    [:to => user.phone_number, :body => "ja bong, joul chet twer ey?"]
  end
end
