class NewbieHandler
  def process!(text, user)
    user.update_status :registering
    user.save
    [:to => user.phone_number, :body => "Orkun bong, chhmous ey? a yu bonnman? srey or bros? nov khiet na?"]
  end
end
