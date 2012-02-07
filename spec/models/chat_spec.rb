require 'spec_helper'

describe Chat do

  let(:chat) do
    create(:chat)
  end

  let(:new_chat) do
    build(:chat)
  end

  let(:active_chat) do
    create(:active_chat)
  end

  let(:active_chat_with_inactivity) do
    create(:active_chat_with_inactivity)
  end

  describe "factory" do
    it "should be valid" do
      new_chat.should be_valid
    end
  end

  it "should not be valid without a user" do
    new_chat.user = nil
    new_chat.should_not be_valid
  end

  it "should not be valid without a friend" do
    new_chat.friend = nil
    new_chat.should_not be_valid
  end

  describe "#active?" do
    it "should only return true for chats which have active users" do
      active_chat.should be_active
      active_chat.active_users.clear
      active_chat.should_not be_active
    end
  end

  describe "#deactivate!" do
    it "should clear the active users" do
      active_chat.deactivate!
      active_chat.active_users.should be_empty
      active_chat.should_not be_active
    end
  end

  describe ".with_inactivity" do
    before do
      active_chat_with_inactivity
      active_chat
      chat
    end

    context "passing no options" do
      it "should return active chats which have been inactive for more than 10 minutes" do
        subject.class.with_inactivity.should == [active_chat_with_inactivity]
      end
    end

    context "passing 11 minutes" do
      it "should return active chats which have been inactive for more than 5 minutes" do
        subject.class.with_inactivity(11.minutes).should == []
      end
    end
  end

  describe ".end_inactive" do
    before do
      chat
      active_chat
      active_chat_with_inactivity
    end

    it "should deactivate the chat with inactivity" do

      chat.should_not be_active
      active_chat.should be_active
      active_chat_with_inactivity.should be_active

      subject.class.end_inactive

      chat.should_not be_active
      active_chat.should be_active
      active_chat_with_inactivity.should_not be_active
    end
  end
end
