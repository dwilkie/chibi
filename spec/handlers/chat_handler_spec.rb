require 'spec_helper'

describe ChatHandler do
  include HandlerHelpers
  include TranslationHelpers

  include_context "replies"

  let(:user) { create(:cambodian) }
  let(:friend) { create(:english) }
  let(:users_new_partner) { create(:cambodian) }
  let(:friends_new_partner) { create(:english) }
  let(:chat) { create(:active_chat, :user => user, :friend => friend) }

  describe "#process!" do
    before do
      chat
    end

    shared_examples_for "associating the message with the current chat" do
      before do
        subject.process!
      end

      it "should associate the message with the current chat" do
        subject.message.chat.should == chat
      end
    end

    shared_examples_for "notifying the user's partner" do
      before do
        subject.process!
      end

      it "should notify the user's partner that the chat has ended and how to update their profile" do
        replies[0].body.should == spec_translate(
          :chat_has_ended,
          :missing_profile_attributes => partner_of_user_who_ended_chat.missing_profile_attributes,
          :friends_screen_name => user_who_ended_chat.screen_id,
          :locale => partner_of_user_who_ended_chat.locale
        )

        replies[0].to.should == partner_of_user_who_ended_chat.mobile_number
        replies[0].chat.should == chat
        partner_of_user_who_ended_chat.reload.active_chat.should be_nil
      end
    end

    shared_examples_for "ending the current chat and starting a new one" do

      it_should_behave_like "notifying the user's partner"

      context "given there is nobody new to chat with" do
        before do
          subject.process!
        end

        it "should notify the user that there is nobody to chat to at this time" do
          replies[1].body.should == spec_translate(
            :could_not_start_new_chat,
            :users_name => nil,
            :locale => user_who_ended_chat.locale
          )

          replies[1].to.should == user_who_ended_chat.mobile_number
          replies[1].chat.should be_nil

          user.reload.active_chat.should be_nil
        end
      end

      context "given there is someone new to chat with" do
        let(:new_chat) { Chat.last }

        before do
          send(new_partner)
          subject.process!
        end

        it "should notify the user that the chat ended the chat and start a new chat for him" do
          replies[1].body.should == spec_translate(
            :new_chat_started,
            :old_friends_screen_name => partner_of_user_who_ended_chat.screen_id,
            :friends_screen_name => send(new_partner).screen_id,
            :users_name => user_who_ended_chat.name,
            :locale => user_who_ended_chat.locale
          )

          replies[1].to.should == user_who_ended_chat.mobile_number

          new_chat.should_not == chat
          user_who_ended_chat.reload.active_chat.should == new_chat
          replies[1].chat.should == new_chat
        end
      end
    end

    shared_examples_for "forwarding the message to the other chat participant" do
      it "should forward the message to the other chat participant and prepend the screen id of the user texting" do
        subject.body = body
        subject.process!

        replies[0].body.should == "#{user_who_texted.screen_id}: #{body}"
        replies[0].to.should == other_chat_participant.mobile_number
        replies[0].chat.should == chat
      end
    end

    shared_examples_for "logging out the user" do

      it_should_behave_like "notifying the user's partner"

      it "should notify the user that he is now offline" do
        subject.process!

        replies[1].body.should == spec_translate(
          :chat_has_ended,
          :friends_screen_name => partner_of_user_who_ended_chat.screen_id,
          :missing_profile_attributes => user_who_ended_chat.missing_profile_attributes,
          :offline => true,
          :locale => user_who_ended_chat.locale
        )

        user_who_ended_chat.reload
        user_who_ended_chat.active_chat.should be_nil
        user_who_ended_chat.should_not be_online
      end
    end

    context "where the message comes from the user who initiated the chat" do
      before do
        setup_handler(user)
      end

      it_should_behave_like "associating the message with the current chat"

      context "and the message text is" do
        context "'new'" do
          before do
            subject.body = "new"
          end

          it_should_behave_like "ending the current chat and starting a new one" do
            let(:user_who_ended_chat) { user }
            let(:partner_of_user_who_ended_chat) { friend }
            let(:new_partner) { :users_new_partner }
          end
        end

        context "'stop'" do
          before do
            subject.body = "stop"
          end

          it_should_behave_like "logging out the user" do
            let(:user_who_ended_chat) { user }
            let(:partner_of_user_who_ended_chat) { friend }
          end
        end

        context "anything other than 'new' or 'stop'" do
          it_should_behave_like "forwarding the message to the other chat participant" do
            let(:body) { "Hi knyom sok 27 nov kt want 2 chat with me? 012 232 234" }
            let(:user_who_texted) { user }
            let(:other_chat_participant) { friend }
          end
        end
      end
    end

    context "where the message comes from the user who is the chat partner" do
      before do
        setup_handler(friend)
      end

      it_should_behave_like "associating the message with the current chat"

      context "and the message text is" do
        context "'new'" do
          before do
            subject.body = "new"
          end

          it_should_behave_like "ending the current chat and starting a new one" do
            let(:user_who_ended_chat) { friend }
            let(:partner_of_user_who_ended_chat) { user }
            let(:new_partner) { :friends_new_partner }
          end
        end

        context "'stop'" do
          before do
            subject.body = "stop"
          end

          it_should_behave_like "logging out the user" do
            let(:user_who_ended_chat) { friend }
            let(:partner_of_user_who_ended_chat) { user }
          end
        end

        context "anything other than 'new' or 'stop'" do
          it_should_behave_like "forwarding the message to the other chat participant" do
            let(:body) { "Hi sok, no sorry m in pp" }
            let(:user_who_texted) { friend }
            let(:other_chat_participant) { user }
          end
        end
      end
    end
  end
end