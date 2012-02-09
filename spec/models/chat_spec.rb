require 'spec_helper'

describe Chat do
  let(:chat) do
    create(:chat)
  end

  let(:new_chat) do
    build(:chat)
  end

  let(:user) do
    create(:english)
  end

  let(:friend) do
    create(:cambodian)
  end

  let(:active_chat) do
    create(:active_chat, :user => user, :friend => friend)
  end

  let(:active_chat_with_inactivity) do
    create(:active_chat_with_inactivity)
  end

  let(:reply_to_user) do
    active_chat.replies.where(:to => user.mobile_number).first
  end

  let(:reply_to_friend) do
    active_chat.replies.where(:to => friend.mobile_number).first
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
      active_chat.replies.should be_empty
    end

    context ":notify => true" do
      it "should notify both active users the the chat has ended" do
        active_chat.deactivate!(:notify => true)

        active_chat.replies.count.should == 2
        reply_to_user.body.should include(friend.screen_id)
        reply_to_friend.body.should include(user.screen_id)
      end
    end

    context ":notify => #<User...>" do
      it "should notify the user specified that the chat has ended" do
        active_chat.deactivate!(:notify => friend)
        active_chat.replies.count.should == 1
        reply_to_friend.body.should include(user.screen_id)
      end
    end
  end

  describe "#forward_message" do
    it "should foward the message to the chat partner" do
      active_chat.forward_message(user, "hello friend")

      active_chat.replies.count.should == 1
      reply_to_friend.body.should include(user.screen_id)
      reply_to_friend.body.should include("hello friend")
    end
  end

  describe "#introduce_participants" do
    it "should send an introduction to both participants" do
      active_chat.introduce_participants

      active_chat.replies.count.should == 2
      reply_to_user.body.should include(friend.screen_id)
      reply_to_friend.body.should include(user.screen_id)
    end

    context ":old_friends_screen_name => 'mary4123'" do
      before do
        active_chat.introduce_participants(:old_friends_screen_name => "mary4123")
      end

      it "should tell the user that their chat with 'mary4123' has ended" do
        reply_to_user.body.should include("mary4123")
      end
    end
  end

  describe "#partner" do
    it "should return the partner of the given user" do
      new_chat.partner(new_chat.user).should == new_chat.friend
      new_chat.partner(new_chat.friend).should == new_chat.user
    end
  end

  describe "#initiator" do
    it "should be an alias for the attribute '#from'" do
      user = User.new

      subject.initiator = new_chat.user
      subject.user.should == new_chat.user

      user = User.new

      subject.user = user
      subject.initiator.should == user
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
      it "should return active chats which have been inactive for more than 11 minutes" do
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
