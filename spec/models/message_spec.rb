require 'spec_helper'

describe Message do
  include AnalyzableExamples
  include ResqueHelpers

  include_context "replies"

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
    let(:message_awaiting_charge_result_for_too_long) { create_unprocessed_message(:awaiting_charge_result) }
    let(:message_awaiting_charge_result) { create_unprocessed_message(:created_at => Time.current) }

    before do
      Timecop.freeze(Time.current)
      message_awaiting_charge_result_for_too_long
      message_awaiting_charge_result
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
        MessageProcessor.should have_queued(message_awaiting_charge_result_for_too_long.id)
        MessageProcessor.should have_queue_size_of(3)
      end

      context "after the job has run" do
        before do
          perform_background_job(:message_processor_queue)
        end

        it "should process the messages" do
          message_awaiting_charge_result_for_too_long.reload.should be_processed
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
        MessageProcessor.should have_queued(message_awaiting_charge_result_for_too_long.id)
        MessageProcessor.should have_queue_size_of(2)
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

  describe "#charge_request_updated!" do
    subject { create(:message) }

    it "should queue the message for processing" do
      do_background_task(:queue_only => true) { subject.charge_request_updated! }
      MessageProcessor.should have_queued(subject.id)
    end
  end

  describe "#body" do
    it "should return an empty string if it is nil" do
      subject.body = nil
      subject.body.should == ""
    end
  end

  describe "queue_for_processing!" do
    it "queue the message for processing" do
      do_background_task(:queue_only => true) { message.queue_for_processing! }
      MessageProcessor.should have_queued(message.id)
    end
  end

  describe "#process" do
    def create_message(*args)
      options = args.extract_options!
      create(:message, *args, {:user => user}.merge(options))
    end

    shared_examples_for "starting a new chat" do
      before do
        Chat.stub(:activate_multiple!)
      end

      it "should try to activate multiple new chats" do
        Chat.should_receive(:activate_multiple!).with(user, :starter => subject, :notify => true)
        subject.process!
      end
    end

    shared_examples_for "not starting a new chat" do
      it "should not start a new chat" do
        Chat.should_not_receive(:activate_multiple!)
        subject.process!
      end
    end

    shared_examples_for "routing the message" do
      it_should_behave_like "starting a new chat"
    end

    shared_examples_for "not routing the message" do
      it "should not try to route the message" do
        Chat.should_not_receive(:intended_for)
        subject.process!
      end
    end

    context "state is 'received'" do
      subject { create_message }

      def stub_user_charge!(result = nil)
        user.stub(:charge!).and_return(result)
      end

      def stub_user_update_profile
        user.stub(:update_profile)
      end

      context "pre-processing" do
        context "the message already belongs to a chat" do
          subject { create_message(:chat => chat, :pre_process => true) }

          after do
            subject.should be_processed
          end

          it_should_behave_like "not routing the message"
        end # context "the message already belongs to a chat"

        context "the message body is" do
          ["stop", "off", "stop all"].each do |stop_variation|
            context "'#{stop_variation}'" do
              subject { create_message(:body => stop_variation) }

              before do
                user.stub(:logout!)
              end

              it "should logout the user" do
                user.should_receive(:logout!)
                subject.process!
                subject.should be_processed
              end
            end # context "'#{stop_variation}'"
          end # ["stop", "off", "stop all"]

          context "indicates the sender wants to use the service" do
            before do
              user.stub(:login!)
              stub_user_charge!
            end

            it "should try to charge the user" do
              user.should_receive(:charge!).with(subject)
              subject.process!
            end

            it "should login the user" do
              user.should_receive(:login!)
              subject.process!
            end

            context "the charge request returns true" do
              before do
                stub_user_charge!(true)
              end

              it "should update the state to 'processed'" do
                subject.process!
                subject.should be_processed
              end
            end # context "the charge request returns true"

            context "the charge request returns false" do
              before do
                stub_user_charge!(false)
              end

              it "should update the state to 'awaiting_charge_result'" do
                subject.process!
                subject.should be_awaiting_charge_result
              end
            end # context "the charge request returns false"
          end # context "indicates the sender wants to use the service"
        end # context "the message body is"
      end # context "pre-processing"

      context "processing" do
        before do
          stub_user_charge!(true)
        end

        context "if an exception is raised" do
          before do
            Chat.stub(:activate_multiple!).and_raise(Resque::TermException.new("SIGTERM"))
          end

          it "should leave the message as 'received'" do
            expect { subject.process! }.to raise_error
            subject.should_not be_processed
          end
        end

        context "unless an exception is raised" do
          after do
            subject.should be_processed
          end

          context "if the message body is" do
            ["new", "'new'", "\"new\""].each do |new_variation|
              context "#{new_variation}" do
                subject { create_message(:body => new_variation) }
                it_should_behave_like "starting a new chat"
              end # context "#{new_variation}"
            end # ["new", "'new'", "\"new\""]

            context "indicates that the sender is not trying to explicitly start a new chat" do
              def stub_chat_intended_for(return_value = nil)
                Chat.stub(:intended_for).and_return(return_value  )
              end

              def stub_user_active_chat(return_value = nil)
                user.stub(:active_chat).and_return(return_value)
              end

              def stub_chat_forward_message
                chat.stub(:forward_message)
              end

              before do
                stub_user_update_profile
              end

              shared_examples_for "forwarding the message" do
                before do
                  stub_chat_forward_message
                end

                it "should forward the message to a particular chat" do
                  chat.should_receive(:forward_message).with(subject)
                  subject.process!
                end
              end

              it "should try to update the users profile from the message text" do
                user.should_receive(:update_profile).with(subject.body)
                subject.process!
              end

              it "should try to determine who the message is intended for" do
                Chat.should_receive(:intended_for).with(subject, :num_recent_chats => 10)
                subject.process!
              end

              context "if the receipient cannot be determined" do
                before do
                  stub_chat_intended_for
                end

                it "try to get the sender's active chat" do
                  user.should_receive(:active_chat)
                  subject.process!
                end

                context "if the sender is not currently chatting" do
                  before do
                    stub_user_active_chat
                  end

                  it_should_behave_like "starting a new chat"
                end # context "if the sender does not have an active chat"

                context "if the sender is currently chatting" do
                  before do
                    stub_user_active_chat(chat)
                  end

                  it_should_behave_like "forwarding the message"
                  it_should_behave_like "not starting a new chat"
                end # context "if the sender is currently chatting"
              end # context "if the receipient cannot be determined"

              context "if the recipient can be determined" do
                before do
                  stub_chat_intended_for(chat)
                end

                it_should_behave_like "forwarding the message"
                it_should_behave_like "not starting a new chat"
              end
            end # context "indicates that the sender is not trying to explicitly start a new chat"
          end # context "if the message body is"
        end # context "unless an exception is raised"
      end # context "processing"
    end # context "state is 'received'"

    context "state is 'awaiting_charge_result'" do
      subject { create_message(:awaiting_charge_result) }

      def create_charge_request(*args)
        options = args.extract_options!
        create(:charge_request, *args, options.merge(:requester => subject))
      end

      after do
        subject.should be_processed
      end

      context "if the charge request failed" do
        before do
          create_charge_request(:failed)
          user.stub(:reply_not_enough_credit!)
        end

        it "should tell the sender they don't have enough credit" do
          user.should_receive(:reply_not_enough_credit!)
          subject.process!
        end

        it_should_behave_like "not routing the message"
      end

      context "if the charge request is not present" do
        it_should_behave_like "routing the message"
      end

      context "if the charge request was successful" do
        before do
          create_charge_request(:successful)
        end

        it_should_behave_like "routing the message"
      end

      context "if the charge request was errored" do
        before do
          create_charge_request(:errored)
        end

        it_should_behave_like "routing the message"
      end
    end

    context "state is 'processed'" do
      subject { create_message(:processed) }

      it "should leave the state as 'processed'" do
        expect { subject.process! }.not_to change { subject.updated_at }
        subject.should be_processed
      end
    end
  end
end
