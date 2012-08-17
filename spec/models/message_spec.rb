require 'spec_helper'

describe Message do
  let(:user) { build(:user) }
  let(:friend) { build(:english) }
  let(:new_friend) { build(:cambodian) }
  let(:message) { create(:message, :user => user) }
  let(:new_message) { build(:message, :user => user) }
  let(:chat) { create(:active_chat, :user => user, :friend => friend) }
  let(:message_with_guid) { create(:message_with_guid, :user => user) }

  describe "factory" do
    it "should be valid" do
      new_message.should be_valid
    end
  end

  it "should not be valid with a duplicate a guid" do
    new_message.guid = message_with_guid.guid
    new_message.should_not be_valid
  end

  it_should_behave_like "analyzable"

  it_should_behave_like "communicable" do
    let(:communicable_resource) { new_message }
  end

  it_should_behave_like "communicable from user" do
    let(:communicable_resource) { new_message }
  end

  it_should_behave_like "chatable" do
    let(:chatable_resource) { message }
  end

  describe "#guid" do
    it "should be mass assignable" do
      message = subject.class.new(:guid => "1234")
      message.guid.should == "1234"
    end
  end

  describe "#origin" do
    it "should be an alias for the attribute '#from'" do
      subject.from = "123"
      subject.origin.should == "123"

      subject.origin = "456"
      subject.from.should == "456"
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

    def stub_match_for_user
      user.stub(:match).and_return(new_friend)
    end

    shared_examples_for "starting a new chat" do
      context "given there is no match for this user" do
        before do
          expect_message { message.process! }
        end

        it "should not reply saying there are no matches at this time" do
          reply_to(user).should be_nil
          user.reload.should_not be_currently_chatting
        end
      end

      context "given there is a match for this user" do
        before do
          stub_match_for_user
          expect_message { message.process! }
        end

        it "should not introduce the match to the partner" do
          reply_to(user, message.chat).should be_nil
        end

        it "should introduce the user to the match" do
          reply = reply_to(new_friend, message.chat).body
          if imitate_user
            reply.should == spec_translate(:greeting_from_unknown_gender, new_friend.locale, user.screen_id)
          else
            reply.should == spec_translate(:forward_message, new_friend.locale, user.screen_id, message.body)
          end
        end
      end
    end

    shared_examples_for "updating the user's locale" do
      def assert_update_locale(body, asserted_locale, expect_reply)
        user.locale.should_not == :en
        message.body = body

        last_reply = create(:delivered_reply_with_alternate_translation, :user => user)

        if expect_reply
          expect_message { message.process! }
          assert_deliver(last_reply.alternate_translation)
        else
          message.process!
        end
        user.locale.should == asserted_locale
      end

      context "if the message body is same as the user's current locale" do
        it "should not update the user's locale nor resend the last reply" do
          assert_update_locale(user.locale.to_s, user.locale, false)
        end
      end

      context "if the message body is different from the user's current locale and is valid" do
        it "should update the user's locale and resend the last reply in the new locale" do
          assert_update_locale("en", :en, true)
        end
      end
    end

    context "given the message body is anything other than 'stop'" do
      let(:offline_user) { create(:offline_user) }
      let(:message_from_offline_user) { create(:message, :user => offline_user) }

      before do
        create(:message, :user => offline_user)
        message_from_offline_user
      end

      it "should put the user online" do
        offline_user.should_not be_online
        expect_message { message_from_offline_user.process! }
        offline_user.should be_online
      end
    end

    context "given the user is currently chatting" do
      before do
        create(:message, :user => user)
        chat
      end

      it_should_behave_like "updating the user's locale"

      context "and the message body is" do
        context "'stop'" do
          before do
            message.body = "stop"
            expect_message { message.process! }
          end

          it "should logout the user but not notify him that he is now offline" do
            reply_to(user).should be_nil
            reply_to(friend).should be_nil
            user.should be_currently_chatting
            user.should_not be_online
          end

          it "should not inform the user's partner how to update their profile" do
            reply_to(friend, chat).should be_nil
            friend.reload
            friend.should_not be_currently_chatting
            friend.should be_online
          end
        end

        ["new", "'new'", "\"new\""].each do |new_variation|
          context "#{new_variation}" do
            before do
              message.body = new_variation
              expect_message { message.process! }
            end

            it_should_behave_like "starting a new chat" do
              let(:imitate_user) { true }
            end

            it "should not inform the user's partner how find a new friend" do
              reply_to(friend, chat).should be_nil
              friend.reload
              friend.should be_currently_chatting
              friend.should be_online
            end
          end
        end

        context "anything else but 'stop' or 'new'" do
          before do
            message.body = "hello"
            expect_locate { expect_message { message.process! } }
          end

          it "should forward the message to the other chat participant and save the message in the chat" do
            # reload message to make sure it's saved
            message.reload.chat.should == chat

            reply_to(friend, chat).body.should == spec_translate(
              :forward_message, friend.locale, user.screen_id, "hello"
            )
          end
        end
      end
    end

    context "given the user is not currently chatting" do

      it_should_behave_like "updating the user's locale"

      context "and the message body is" do
        context "'stop'" do
          before do
            message.body = "stop"
            expect_message { message.process! }
          end

          it "should logout the user but not notify him that he is now offline" do
            reply_to(user).should be_nil
            user.should_not be_online
          end
        end

        context "not introducable" do
          context "and a match is found for the user" do
            before do
              stub_match_for_user
            end

            it "should introduce the user to the match by imitating the user" do
              non_introducable_examples.each do |example|
                message = build(:message, :user => user, :body => example.upcase)
                expect_message  { message.process! }
                reply_to(new_friend).body.should == spec_translate(:greeting_from_unknown_gender, new_friend.locale, user.screen_id)
              end
            end
          end
        end

        context "anything else but 'stop'" do
          before do
            message.body = "hello"
            user.stub(:update_profile)
          end

          it_should_behave_like "starting a new chat" do
            let(:imitate_user) { true }
          end

          it "should try to update the users profile from the message text" do
            user.should_receive(:update_profile).with("hello")
            expect_message { message.process! }
          end

          context "and the user is offline" do
            let(:offline_user) { build(:offline_user) }

            before do
              message.body = ""
              message.user = offline_user
              expect_message { message.process! }
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
