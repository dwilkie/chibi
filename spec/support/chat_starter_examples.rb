shared_examples_for "a chat starter" do
  let(:chat) { create(:chat, :starter => starter) }
  it "should trigger many chats" do
    starter.triggered_chats.should == [chat]
  end
end
