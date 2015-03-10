shared_examples_for "a chat starter" do
  let(:chat) { create(:chat, :starter => starter) }
  it "should trigger many chats" do
    expect(starter.triggered_chats).to eq([chat])
  end
end
