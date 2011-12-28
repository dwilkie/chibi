module SharedExamples
  shared_examples_for "starting a chat" do
    let(:new_chat) { Chat.last }

    before do
      subject.body = defined?(body) ? body : ""
    end

    it "should start a new chat session" do
      send(method)
      new_chat.user.should == reference_user
      new_chat.friend.should == reference_chat_friend
    end
  end
end
