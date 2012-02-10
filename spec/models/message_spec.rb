require 'spec_helper'

describe Message do

  let(:user) { build(:user) }
  let(:message) { create(:message, :user => user) }
  let(:new_message) { build(:message, :user => user) }
  let(:chat) { create(:chat, :user => user) }

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

  describe "#process!", :focus do
    include TranslationHelpers
    include_context "replies"

    context "given the user is not currently chatting" do
      context "and the message body is" do

        context "'stop'" do
          before do
            new_message.body = "stop"
            new_message.process!
          end

          it "should logout the user and notify him that he is now offline" do
            reply_to(user).body.should == spec_translate(
              :anonymous_logged_out, user.locale
            )
            user.reload.should_not be_online
          end
        end

        context "anything else but 'stop'" do
          context "and the user is offline" do
            let(:offline_user) { build(:offline_user) }

            before do
              new_message.user = offline_user
              new_message.process!
            end

            it "should login the user" do
              offline_user.reload.should be_online
            end
          end

          context "and there is no match for this user" do
            before do
              new_message.process!
            end

            it "should reply saying there are no matches at this time" do
              reply_to(user).body.should == spec_translate(:could_not_start_new_chat, user.locale)
              user.should_not be_currently_chatting
            end
          end

          context "and there is a match for this user" do
            let(:friend) { create(:english) }

            before do
              User.stub(:matches).and_return([friend])
              new_message.process!
            end

            it "should introduce the participants of the chat", :focus do
              reply_to(user, new_message.chat).body.should == spec_translate(
                :anonymous_new_chat_started, user.locale, friend.screen_id
              )
              reply_to(friend, new_message.chat).body.should == spec_translate(
                :anonymous_new_chat_started, friend.locale, user.screen_id
              )
            end
          end
        end
      end
    end
  end
end
