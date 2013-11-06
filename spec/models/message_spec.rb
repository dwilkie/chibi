require 'spec_helper'

describe Message do
  include AnalyzableExamples
  include ResqueHelpers

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

    def create_resource(*args)
      create(:message, *args)
    end
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
    def create_unprocessed_message(*args)
      options = args.extract_options!
      create(:message, *args, {:created_at => 5.minutes.ago}.merge(options))
    end

    let(:unprocessed_message) { create_unprocessed_message }
    let(:recently_received_message) { create_unprocessed_message(:created_at => 2.minutes.ago) }
    let(:unprocessed_message_with_chat) { create_unprocessed_message(:chat => chat) }
    let(:message_awaiting_charge_result) { create_unprocessed_message(:awaiting_charge_result) }
    let(:ignored_message) { create_unprocessed_message(:ignored) }

    before do
      Timecop.freeze(Time.now)
      message_awaiting_charge_result
      ignored_message
      unprocessed_message
      processed_message
      recently_received_message
      unprocessed_message_with_chat
      message
    end

    after do
      Timecop.return
    end

    context "passing no options" do
      before do
        do_background_task(:queue_only => true) { subject.class.queue_unprocessed }
      end

      it "should queue for processing any non processed messages with no chat that were created more than 30 secs ago" do
        MessageProcessor.should have_queued(unprocessed_message.id)
        MessageProcessor.should have_queued(recently_received_message.id)
        MessageProcessor.should have_queue_size_of(2)
      end

      context "after the job has run" do
        before do
          perform_background_job(:message_processor_queue)
        end

        it "should process the messages" do
          ignored_message.reload.should_not be_processed
          message_awaiting_charge_result.reload.should_not be_processed
          unprocessed_message.reload.should be_processed
          processed_message.reload.should be_processed
          recently_received_message.reload.should be_processed
          unprocessed_message_with_chat.reload.should be_processed
          message.reload.should_not be_processed
        end
      end
    end

    context "passing :timeout => 5.minutes.ago" do
      before do
        do_background_task(:queue_only => true) { subject.class.queue_unprocessed(:timeout => 5.minutes.ago) }
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

    describe "before the message is processed" do
      context "if the message was already processed" do
        subject { processed_message }

        it "should not do anything" do
          expect { subject.process! }.not_to change { subject.updated_at }
        end
      end

      context "for a message that already belongs to a chat" do
        subject { create(:message, :user => user, :chat => chat) }

        it "should not do anything" do
          expect { subject.process! }.not_to change { subject.updated_at }
          subject.should_not be_processed
        end
      end

      context "the message body is" do
        ["stop", "off", "stop all"].each do |stop_variation|
          context "'#{stop_variation}'" do
            subject { create(:message, :user => user, :body => stop_variation) }

            it "should logout the user" do
              subject.process!
              user.should be_offline
              subject.should be_processed
            end
          end
        end

        context "anything else" do
          let(:offline_user) { create(:user, :offline) }
          subject { create(:message, :user => offline_user, :body => "hello") }

          it "should put the user online" do
            expect_locate { subject.process! }
            offline_user.should be_online
          end
        end
      end
    end

    describe "processing the message" do
      subject { create(:message, :user => user) }

      def stub_match_for_user
        new_friend
      end

      before do
        user.stub(:charge!).and_return(true)
      end

      it "should try to update the users profile from the message text" do
        user.should_receive(:update_profile).with(subject.body)
        expect_message { subject.process! }
      end

      context "charging the user" do
        it "should try to charge the sender" do
          user.should_receive(:charge!)
          subject.process!
        end

        context "given the charge request returns true" do
          it "should process the message" do
            subject.process!
            subject.should be_processed
          end
        end

        context "given the charge request returns nil" do
          before do
            user.stub(:charge!).and_return(nil)
          end

          it "should await the result of the charge request" do
            subject.process!
            subject.should be_awaiting_charge_result
          end
        end
      end

      context "if an exception is raised" do
        before do
          user.stub(:match).and_raise(Resque::TermException.new("SIGTERM"))
        end

        it "should not mark the message as 'processed'" do
          expect { subject.process! }.to raise_error
          subject.should_not be_processed
        end
      end

      context "unless an exception is raised" do
        it "should mark the message as 'processed'" do
          subject.process!
          subject.should be_processed
        end
      end

      shared_examples_for "forwarding the message to a previous chat partner" do
        context "if the message body contains the screen id of a recent previous chat partner" do
          let(:bob) { create(:user, :name => "bob") }
          let(:chat_with_bob) { create(:chat, :user => user, :friend => bob) }
          let!(:reply_from_bob) { create(:reply, :user => user, :chat => chat_with_bob) }

          subject { create(:message, :user => user, :body => "Hi bob how are you?") }

          it "should forward the message to the previous chat partner" do
            expect_locate { expect_message { subject.process! } }

            subject.reload.chat.should == chat_with_bob

            reply_to(bob, chat_with_bob).body.should == spec_translate(
              :forward_message, bob.locale, user.screen_id, "Hi bob how are you?"
            )
          end
        end
      end

      shared_examples_for "starting a new chat" do
        context "given there is no match for this user" do
          before do
            subject.process!
          end

          it "should not reply saying there are no matches at this time" do
            reply_to(user).should be_nil
            user.reload.should_not be_currently_chatting
          end
        end

        context "given there is a match for this user" do
          before do
            stub_match_for_user
            expect_message { subject.process! }
          end

          it "should not introduce the match to the partner" do
            reply_to(user, subject.chat).should be_nil
          end

          it "should introduce the user to the match" do
            reply = reply_to(new_friend, subject.chat).body
            reply.should =~ /#{spec_translate(:forward_message_approx, new_friend.locale, user.screen_id)}/
          end

          it "should trigger a new chat" do
            subject.triggered_chats.should == [Chat.last]
          end
        end
      end

      context "given the sender is currently chatting" do
        let!(:current_chat) { create(:chat, :active, :user => user, :friend => friend) }

        it_should_behave_like "forwarding the message to a previous chat partner"

        context "and the message body is" do
          ["new", "'new'", "\"new\""].each do |new_variation|
            context "#{new_variation}" do
              subject { create(:message, :body => new_variation, :user => user) }

              it_should_behave_like "starting a new chat"

              it "should not inform the user's partner how find a new friend" do
                reply_to(friend, current_chat).should be_nil
                friend.reload
                friend.should be_currently_chatting
                friend.should be_online
              end
            end
          end

          context "anything else" do
            subject { create(:message, :user => user, :body => "hello") }

            it "should forward the message to the other chat participant and save the message in the chat" do
              expect_locate { expect_message { subject.process! } }

              # reload message to make sure it's saved
              subject.reload.chat.should == current_chat

              reply_to(friend, current_chat).body.should == spec_translate(
                :forward_message, friend.locale, user.screen_id, "hello"
              )
            end
          end
        end
      end

      context "given the user is not currently chatting" do
        it_should_behave_like "forwarding the message to a previous chat partner"
        it_should_behave_like "starting a new chat"
      end
    end
  end
end
