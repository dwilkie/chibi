shared_context "existing users" do
  USERS = [:dave, :nok, :mara, :alex, :joy]

  USERS.each do |user|
    let(user) { create(user) }
  end

  def load_users
    USERS.each do |user|
      send(user)
    end
  end
end

shared_context "replies" do
  let(:replies) { Reply.all }

  def reply_to(reference_user, reference_chat = nil)
    scope = Reply.where(:to => reference_user.mobile_number)
    scope = scope.where(:chat_id => reference_chat.id) if reference_chat
    scope.last
  end
end
