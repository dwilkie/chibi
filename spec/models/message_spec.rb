require 'rails_helper'

describe Message do
  include AnalyzableExamples
  include ActiveJobHelpers
  include MessagingHelpers
  include EnvHelpers

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
      expect(new_message).to be_valid
    end
  end

  describe "callbacks" do
    describe "before_validation" do
      it "should normalize the channel" do
        subject.channel = "SMART"
        subject.valid?
        expect(subject.channel).to eq("smart")
        subject.channel = nil
        subject.valid?
        expect(subject.channel).to eq(nil)
      end

      it "should normalize the 'to' number" do
        subject.to = "+2442"
        subject.valid?
        expect(subject.to).to eq("2442")
        subject.to = "+14156926280"
        subject.valid?
        expect(subject.to).to eq("14156926280")
        subject.to = nil
        subject.valid?
        expect(subject.to).to eq(nil)
      end
    end
  end

  it "should not be valid with a duplicate a guid" do
    new_message.guid = message_with_guid.guid
    expect(new_message).not_to be_valid
  end

  it_should_behave_like "a chat starter" do
    let(:starter) { message }
  end

  it_should_behave_like "analyzable" do
    let(:group_by_column) { :created_at }

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

  describe ".from_nuntium?(params = {})" do
    describe "from nuntium" do
      let(:params) { nuntium_message_params }
      it { expect(described_class.from_nuntium?(params)).to eq(true) }
    end

    describe "from twilio" do
      let(:params) { twilio_message_params }
      it { expect(described_class.from_nuntium?(params)).to eq(false) }
    end
  end

  # nuntium
  describe ".accept_messages_from_channel?(params = {})" do
    let(:params) { nuntium_message_params(:channel => nuntium_channel) }

    before do
      stub_env(:nuntium_messages_enabled_channels => nuntium_channel)
    end

    context "given the channel is nuntium enabled" do
      let(:nuntium_channel) { "smart" }

      it { expect(described_class.accept_messages_from_channel?(params)).to eq(true) }
    end

    context "given the channel is not nuntium enabled" do
      let(:nuntium_channel) { nil }

      it { expect(described_class.accept_messages_from_channel?(params)).to eq(false) }
    end
  end

  describe "'.from' methods" do
    let(:from) { generate(:mobile_number) }
    let(:to) { "2442" }
    let(:guid) { generate(:guid) }
    let(:body) { "foo" }
    let(:channel) { "smart" }

    def assert_new_message!
      expect(new_message.from).to eq(from)
      expect(new_message.body).to eq(body)
      expect(new_message.guid).to eq(guid)
      expect(new_message.to).to eq(to)
      expect(new_message.channel).to eq(channel)
    end

    describe ".from_smsc(params = {})" do
      let(:guid) { nil }

      let(:new_message) do
        described_class.from_smsc(
          :from => from, :body => body, :channel => channel, :to => to
        )
      end

      it { assert_new_message! }
    end

    describe ".from_aggregator(params = {})" do
      let(:new_message) do
        described_class.from_aggregator(
          message_params(:from => from, :body => body, :guid => guid, :channel => channel, :to => to)
        )
      end

      describe "from twilio" do
        let(:channel) { "twilio" }
        let(:to) { "+14156926280" }

        def message_params(params = {})
          twilio_message_params(params)
        end

        it { assert_new_message! }
      end

      describe "from nuntium" do
        def message_params(params = {})
          nuntium_message_params(params)
        end

        it { assert_new_message! }
      end
    end
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

    let(:job_args) { enqueued_jobs.map { |job| job[:args].first } }

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
      it "should queue for processing any non processed messages with no chat that were created more than 30 secs ago" do
        trigger_job(:queue_only => true) { described_class.queue_unprocessed }
        expect(enqueued_jobs.size).to eq(3)
        expect(job_args).to contain_exactly(
          unprocessed_message.id,
          recently_received_message.id,
          message_awaiting_charge_result_for_too_long.id
        )
      end

      context "after the job has run" do
        before do
          trigger_job { described_class.queue_unprocessed }
        end

        it "should process the messages" do
          expect(message_awaiting_charge_result_for_too_long.reload).to be_processed
          expect(message_awaiting_charge_result.reload).not_to be_processed
          expect(unprocessed_message.reload).to be_processed
          expect(processed_message.reload).to be_processed
          expect(recently_received_message.reload).to be_processed
          expect(unprocessed_message_with_chat.reload).to be_processed
          expect(message.reload).not_to be_processed
        end
      end
    end

    context "passing :timeout => 5.minutes.ago" do
      before do
        trigger_job(:queue_only => true) { described_class.queue_unprocessed(:timeout => 5.minutes.ago) }
      end

      it "should queue for processing any non processed message that was created more than 5 mins ago" do
        expect(enqueued_jobs.size).to eq(2)
        expect(job_args).to contain_exactly(
          unprocessed_message.id,
          message_awaiting_charge_result_for_too_long.id
        )
      end
    end
  end

  describe "#origin" do
    it "should be an alias for the attribute '#from'" do
      sample_number = generate(:mobile_number)
      subject.from = sample_number
      expect(subject.origin).to eq(sample_number)

      sample_number = generate(:mobile_number)
      subject.origin = sample_number
      expect(subject.from).to eq(sample_number)
    end
  end

  describe "#charge_request_updated!" do
    subject { create(:message) }

    it "should queue the message for processing" do
      trigger_job(:queue_only => true) { subject.charge_request_updated! }
      job = enqueued_jobs.first
      expect(job[:args].first).to eq(subject.id)
    end
  end

  describe "#body" do
    it "should return an empty string if it is nil" do
      subject.body = nil
      expect(subject.body).to eq("")
    end
  end

  describe "queue_for_processing!" do
    it "queue the message for processing" do
      trigger_job(:queue_only => true) { message.queue_for_processing! }
      job = enqueued_jobs.last
      expect(job[:args].first).to eq(message.id)
    end
  end

  describe "#process" do
    def create_message(*args)
      options = args.extract_options!
      create(:message, *args, {:user => user}.merge(options))
    end

    shared_examples_for "starting a new chat" do
      before do
        allow(Chat).to receive(:activate_multiple!)
      end

      it "should try to activate multiple new chats" do
        expect(Chat).to receive(:activate_multiple!).with(user, :starter => subject, :notify => true)
        subject.process!
      end
    end

    shared_examples_for "not starting a new chat" do
      it "should not start a new chat" do
        expect(Chat).not_to receive(:activate_multiple!)
        subject.process!
      end
    end

    shared_examples_for "routing the message" do
      it_should_behave_like "starting a new chat"
    end

    shared_examples_for "not routing the message" do
      it "should not try to route the message" do
        expect(Chat).not_to receive(:intended_for)
        subject.process!
      end
    end

    context "state is 'received'" do
      subject { create_message }

      def stub_user_charge!(result = nil)
        allow(user).to receive(:charge!).and_return(result)
      end

      def stub_user_update_profile
        allow(user).to receive(:update_profile)
      end

      context "pre-processing" do
        context "the message already belongs to a chat" do
          subject { create_message(:chat => chat, :pre_process => true) }

          after do
            expect(subject).to be_processed
          end

          it_should_behave_like "not routing the message"
        end # context "the message already belongs to a chat"

        context "the message body is" do
          ["stop", "off", "stop all"].each do |stop_variation|
            context "'#{stop_variation}'" do
              subject { create_message(:body => stop_variation) }

              before do
                allow(user).to receive(:logout!)
              end

              it "should logout the user" do
                expect(user).to receive(:logout!)
                subject.process!
                expect(subject).to be_processed
              end
            end # context "'#{stop_variation}'"
          end # ["stop", "off", "stop all"]

          context "indicates the sender wants to use the service" do
            before do
              allow(user).to receive(:login!)
              stub_user_charge!
            end

            it "should try to charge the user" do
              expect(user).to receive(:charge!).with(subject)
              subject.process!
            end

            it "should login the user" do
              expect(user).to receive(:login!)
              subject.process!
            end

            context "the charge request returns true" do
              before do
                stub_user_charge!(true)
              end

              it "should update the state to 'processed'" do
                subject.process!
                expect(subject).to be_processed
              end
            end # context "the charge request returns true"

            context "the charge request returns false" do
              before do
                stub_user_charge!(false)
              end

              it "should update the state to 'awaiting_charge_result'" do
                subject.process!
                expect(subject).to be_awaiting_charge_result
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
            allow(Chat).to receive(:activate_multiple!).and_raise(ArgumentError)
          end

          it "should leave the message as 'received'" do
            expect { subject.process! }.to raise_error
            expect(subject).not_to be_processed
          end
        end

        context "unless an exception is raised" do
          after do
            expect(subject).to be_processed
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
                allow(Chat).to receive(:intended_for).and_return(return_value  )
              end

              def stub_user_active_chat(return_value = nil)
                allow(user).to receive(:active_chat).and_return(return_value)
              end

              def stub_chat_forward_message
                allow(chat).to receive(:forward_message)
              end

              before do
                stub_user_update_profile
              end

              shared_examples_for "forwarding the message" do
                before do
                  stub_chat_forward_message
                end

                it "should forward the message to a particular chat" do
                  expect(chat).to receive(:forward_message).with(subject)
                  subject.process!
                end
              end

              it "should try to update the users profile from the message text" do
                expect(user).to receive(:update_profile).with(subject.body)
                subject.process!
              end

              it "should try to determine who the message is intended for" do
                expect(Chat).to receive(:intended_for).with(subject, :num_recent_chats => 10)
                subject.process!
              end

              context "if the receipient cannot be determined" do
                before do
                  stub_chat_intended_for
                end

                it "try to get the sender's active chat" do
                  expect(user).to receive(:active_chat)
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
        expect(subject).to be_processed
      end

      context "if the charge request failed" do
        before do
          create_charge_request(:failed)
          allow(user).to receive(:reply_not_enough_credit!)
        end

        it "should tell the sender they don't have enough credit" do
          expect(user).to receive(:reply_not_enough_credit!)
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
        expect(subject).to be_processed
      end
    end
  end
end
