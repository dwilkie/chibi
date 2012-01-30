shared_context "existing users" do
  USERS = [:dave, :nok, :mara, :alex]

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
  let(:last_reply) { Reply.last }

  let(:reply_to_user) do
    replies[0]
  end

  let(:reply_to_friend) do
    replies[1]
  end
end
