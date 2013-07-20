require 'spec_helper'

describe Message do
  include AnalyzableExamples

  let(:user) { create(:user) }
  let(:friend) { create(:user, :english) }
  let(:new_friend) { create(:user, :cambodian) }
  let(:message) { create(:message, :user => user) }
  let(:new_message) { build(:message, :user => user) }
  let(:chat) { create(:chat, :active, :user => user, :friend => friend) }
  let(:message_with_guid) { create(:message, :with_guid, :user => user) }
  let(:processed_message) { create(:message, :processed, :created_at => 10.minutes.ago, :user => user) }
  let(:subject) { build(:message, :without_user) }

  describe "factory" do
    it "should be valid" do
      new_message.should be_valid
    end
  end

  it "should not be valid with a duplicate a guid" do
    new_message.guid = message_with_guid.guid
    new_message.should_not be_valid
  end

  it_should_behave_like "a chat starter" do
    let(:starter) { message }
  end

  it_should_behave_like "analyzable" do
    let(:group_by_column) { :created_at }
    let(:excluded_resource) { nil }
  end

  it_should_behave_like "communicable" do
    let(:communicable_resource) { message }
  end

  it_should_behave_like "communicable from user" do
    let(:communicable_resource) { message }
  end

  it_should_behave_like "chatable" do
    let(:chatable_resource) { message }
  end

  describe ".queue_unprocessed" do
    let(:unprocessed_message) { create(:message, :created_at => 5.minutes.ago) }
    let(:recently_received_message) { create(:message, :created_at => 2.minutes.ago) }
    let(:unprocessed_message_with_chat) { create(:message, :chat => chat, :created_at => 5.minutes.ago) }

    before do
      ResqueSpec.reset!
      Timecop.freeze(Time.now)
      unprocessed_message
      processed_message
      recently_received_message
      unprocessed_message_with_chat
      message
    end

    after do
      Timecop.return
    end

    it "should leave mark messages with chats as processed" do
      subject.class.queue_unprocessed
      unprocessed_message.reload.should_not be_processed
      processed_message.reload.should be_processed
      recently_received_message.reload.should_not be_processed
      unprocessed_message_with_chat.reload.should be_processed
      message.reload.should_not be_processed
    end

    context "passing no options" do
      before do
        subject.class.queue_unprocessed
      end

      it "should queue for processing any non processed messages with no chat that were created more than 30 secs ago" do
        MessageProcessor.should have_queued(unprocessed_message.id)
        MessageProcessor.should have_queued(recently_received_message.id)
        MessageProcessor.should have_queue_size_of(2)
      end
    end

    context "passing :timeout => 5.minutes.ago" do
      before do
        subject.class.queue_unprocessed(:timeout => 5.minutes.ago)
      end

      it "should queue for processing any non processed message that was created more than 5 mins ago" do
        MessageProcessor.should have_queued(unprocessed_message.id)
        MessageProcessor.should have_queue_size_of(1)
      end
    end
  end

  describe "#origin" do
    it "should be an alias for the attribute '#from'" do
      sample_number = generate(:mobile_number)
      subject.from = sample_number
      subject.origin.should == sample_number

      sample_number = generate(:mobile_number)
      subject.origin = sample_number
      subject.from.should == sample_number
    end
  end

  describe "#body" do
    it "should return an empty string if it is nil" do
      subject.body = nil
      subject.body.should == ""
    end
  end

  describe "queue_for_processing!" do
    before do
      ResqueSpec.reset!
    end

    it "queue the message for processing" do
      message.queue_for_processing!
      MessageProcessor.should have_queued(message.id)
    end
  end

  describe "#process!" do
    include TranslationHelpers
    include MessagingHelpers

    include_context "replies"

    def stub_match_for_user
      user.stub(:match).and_return(new_friend)
    end

    context "if an exception is raised during the processing" do
      before do
        user.stub(:match).and_raise(Resque::TermException.new("SIGTERM"))
      end

      it "should not mark the message as 'processed'" do
        message.should be_received
        expect { message.process! }.to raise_error
        message.should_not be_processed
      end
    end

    context "unless an exception is raised during the processing" do
      it "should mark the message as 'processed'" do
        message.should be_received
        expect_message { message.process! }
        message.should be_processed
      end
    end

    context "for an already processed message" do
      before do
        stub_match_for_user
      end

      it "should not do anything" do
        processed_message.process!
        reply_to(new_friend).should be_nil
      end
    end

    context "for a message that already belongs to a chat" do
      let(:message_in_chat) { create(:message, :user => user, :chat => chat) }

      before do
        stub_match_for_user
      end

      it "should not do anything" do
        message_in_chat.process!
        message_in_chat.should_not be_processed
      end
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
            reply.should =~ /#{spec_translate(:forward_message_approx, new_friend.locale, user.screen_id)}/
          else
            reply.should == spec_translate(
              :forward_message, new_friend.locale, user.screen_id, message.body
            )
          end
        end

        it "should trigger a new chat" do
          message.triggered_chats.should == [Chat.last]
        end
      end
    end

    shared_examples_for "forwarding the message to a previous chat partner" do
      context "if the message body contains the screen id of a recent previous chat partner" do
        let(:bob) { create(:user, :name => "bob") }
        let(:chat_with_bob) { create(:chat, :user => user, :friend => bob) }
        let(:reply_from_bob) { create(:reply, :user => user, :chat => chat_with_bob) }

        before do
          reply_from_bob
          message.body = "Hi bob how are you?"
        end

        it "should forward the message to the previous chat partner" do
          expect_locate { expect_message { message.process! } }

          message.reload.chat.should == chat_with_bob

          reply_to(bob, chat_with_bob).body.should == spec_translate(
            :forward_message, bob.locale, user.screen_id, "Hi bob how are you?"
          )
        end
      end
    end

    context "given the message body is anything other than 'stop'" do
      let(:offline_user) { create(:user, :offline) }
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

      it_should_behave_like "forwarding the message to a previous chat partner"

      context "and the message body is" do
        ["stop", "off", "stop all"].each do |stop_variation|
          context "'#{stop_variation}'" do
            before do
              message.body = stop_variation
              expect_message { message.process! }
            end

            def assert_logout
              user.should be_offline
              message.should be_processed
            end

            it "should logout the user but not notify him that he is now offline" do
              assert_logout
              reply_to(user).should be_nil
              reply_to(friend).should be_nil
              user.should be_currently_chatting
            end

            it "should not inform the user's partner how to update their profile" do
              assert_logout
              reply_to(friend, chat).should be_nil
              friend.reload
              friend.should_not be_currently_chatting
              friend.should be_online
            end
          end
        end

        ["new", "'new'", "\"new\""].each do |new_variation|
          context "#{new_variation}" do
            before do
              message.body = new_variation
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

      it_should_behave_like "forwarding the message to a previous chat partner"

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
                reply_to(new_friend).body.should =~ /#{spec_translate(:forward_message_approx, new_friend.locale, user.screen_id)}/
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
            let(:offline_user) { build(:user, :offline) }

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
