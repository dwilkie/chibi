require 'spec_helper'

describe Message do

  let(:user) { build(:user) }
  let(:friend) { build(:english) }
  let(:new_friend) { build(:cambodian) }
  let(:message) { create(:message, :user => user) }
  let(:new_message) { build(:message, :user => user) }
  let(:chat) { create(:active_chat, :user => user, :friend => friend) }

  describe "factory" do
    it "should be valid" do
      new_message.should be_valid
    end
  end

  it_should_behave_like "communicable" do
    let(:communicable_resource) { new_message }
  end

  it_should_behave_like "chatable" do
    let(:chatable_resource) { new_message }
  end

  describe ".filter_by" do
    let(:another_message) { create(:message) }

    before do
      another_message
      message
    end

    context "passing no params" do
      it "should return all messages ordered by created at date" do
        subject.class.filter_by.should == [another_message, message]
      end
    end

    context ":user_id => 2" do
      it "should return all messages with the given user id" do
        subject.class.filter_by(:user_id => user.id).should == [message]
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
    include TranslationHelpers
    include MessagingHelpers

    include_context "replies"

    shared_examples_for "starting a new chat" do
      context "given there is no match for this user" do
        before do
          expect_message { new_message.process! }
        end

        it "should reply saying there are no matches at this time" do
          reply_to(user).body.should == spec_translate(:could_not_start_new_chat, user.locale)
          user.reload.should_not be_currently_chatting
        end
      end

      context "given there is a match for this user" do
        before do
          user.stub(:match).and_return(new_friend)
          expect_message { new_message.process! }
        end

        it "should introduce the participants of the chat" do
          reply_to(user, new_message.chat).body.should == spec_translate(
            :anonymous_new_chat_started, user.locale, new_friend.screen_id
          )
          reply_to(new_friend, new_message.chat).body.should == spec_translate(
            :anonymous_new_chat_started, new_friend.locale, user.screen_id
          )
        end
      end
    end

    shared_examples_for "logging out the user" do
      before do
        expect_message { new_message.process! }
      end

      it "should logout the user and notify him that he is now offline" do
        reply_to(user).body.should == spec_translate(:anonymous_logged_out, user.locale)
        user.reload
        user.should_not be_currently_chatting
        user.should_not be_online
      end
    end

    context "given the user is currently chatting" do
      before do
        chat
      end

      context "and the message body is" do

        shared_examples_for "notifying the user's partner" do
          before do
            expect_message { new_message.process! }
          end

          it "should notify the user's partner that the chat has ended and how to update their profile" do
            replies_to(friend, chat).count.should == 1

            reply_to(friend, chat).body.should == spec_translate(
              :anonymous_chat_has_ended, friend.locale
            )

            friend.reload
            friend.should_not be_currently_chatting
            friend.should be_online
          end
        end

        context "'stop'" do
          before do
            new_message.body = "stop"
          end

          it_should_behave_like "logging out the user"
          it_should_behave_like "notifying the user's partner"
        end

        context "'new'" do
          before do
            new_message.body = "new"
          end

          it_should_behave_like "starting a new chat"
          it_should_behave_like "notifying the user's partner"
        end

        context "anything else but 'stop' or 'new'" do
          before do
            new_message.body = "hello"
            expect_message { new_message.process! }
          end

          it "should forward the message to the other chat participant" do
            reply_to(friend, chat).body.should == spec_translate(
              :forward_message, friend.locale, user.screen_id, "hello"
            )
          end
        end
      end
    end

    context "and the user is not currently chatting" do
      context "and the message body is" do
        context "'stop'" do
          before do
            new_message.body = "stop"
          end

          it_should_behave_like "logging out the user"
        end

        context "anything else but 'stop'" do
          before do
            new_message.body = "hello"
            user.stub(:update_profile)
          end

          it_should_behave_like "starting a new chat"

          it "should try to update the users profile from the message text" do
            user.should_receive(:update_profile).with("hello", :online => true)
            expect_message { new_message.process! }
          end

          context "and the user is offline" do
            let(:offline_user) { build(:offline_user) }

            before do
              new_message.body = ""
              new_message.user = offline_user
              expect_message { new_message.process! }
            end

            it "should login the user" do
              offline_user.reload.should be_online
            end
          end
        end
      end
    end
  end
end
