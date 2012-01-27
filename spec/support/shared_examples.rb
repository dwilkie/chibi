module SharedExamples
  shared_examples_for "starting a chat" do

    let(:new_chat) { Chat.first }

    before do
      subject.body = defined?(body) ? body : ""
    end

    it "should start a new chat session" do
      Chat.count.should == 0
      send(method)
      Chat.count.should == 1
      new_chat.active_users.count.should == 2
      new_chat.user.active_chat.should == new_chat
      new_chat.friend.active_chat.should == new_chat
      if defined?(reference_user)
        new_chat.user.should == reference_user
        reference_user.active_chat.should == new_chat
      end
    end
  end
end
