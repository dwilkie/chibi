class ReadyHandler
  def process!(text, user)
    text.split.each do |value|
      user.interests.create :value => value
    end
    user.update_status :looking_for
    user.save
    [:to => user.phone_number, :body => "ja, jong ban met srey or pros?"]
  end
end
