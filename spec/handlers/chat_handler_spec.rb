require 'spec_helper'

describe ChatHandler do
  include HandlerHelpers

  include_context "replies"

  let(:user) { create(:user) }
  let(:friend) { create(:user) }
  let(:chat) { create(:active_chat, :user => user, :friend => friend) }

  describe "#process!" do
    before do
      chat
    end

    context "where the message comes from the user who initiated the chat" do
      before do
        setup_handler(user)
      end

      it "should pass the message on to the chat friend and prepend the screen name of the user" do
        subject.body = "Hi knyom sok 27 nov kt want 2 chat with me? 012 232 234"
        subject.process!

        last_reply.body.should == "#{user.screen_id}: Hi knyom sok 27 nov kt want 2 chat with me? 012 232 234"
        last_reply.to.should == friend.mobile_number
      end
    end

    context "where the message comes from the user who is the chat partner" do
      before do
        setup_handler(friend)
      end

      it "should pass the message on to the user who initiated the chat and prepend the screen name of the friend" do
        subject.body = "Hi sok, no sorry m in pp"
        subject.process!

        last_reply.body.should == "#{friend.screen_id}: Hi sok, no sorry m in pp"
        last_reply.to.should == user.mobile_number
      end
    end
  end
end
