require 'spec_helper'

describe Message do

  let(:message) { create(:message) }
  let(:new_message) { build(:message) }
  let(:chat) { create(:chat) }

  describe "factory" do
    it "should be valid" do
      new_message.should be_valid
    end
  end

  it "should not be valid without a user" do
    new_message.user = nil
    new_message.should_not be_valid
  end

  it "should not be valid without a 'from'" do
    new_message.from = nil
    new_message.should_not be_valid
  end

  describe "associations" do
    context "when saving a message with an associated chat" do
      before do
        chat
        message
      end

      it "should touch the chat" do
        original_chat_timestamp = chat.updated_at

        message.chat = chat
        message.save

        chat.reload.updated_at.should > original_chat_timestamp
      end
    end
  end

  describe "#origin" do
    it "should be an alias for the attribute '#from'" do
      subject.from = 123
      subject.origin.should == 123

      subject.origin = 456
      subject.from.should == 456
    end
  end

  describe "#body" do
    it "should return an empty string if it is nil" do
      subject.body = nil
      subject.body.should == ""
    end
  end

  describe "#process!" do
    let(:message_handler) { mock(MessageHandler).as_null_object }

    before do
      MessageHandler.stub(:new).and_return(message_handler)
    end

    it "should delegate to a new MessageHandler passing itself" do
      message_handler.should_receive(:process!).with(subject)
      subject.process!
    end
  end
end
