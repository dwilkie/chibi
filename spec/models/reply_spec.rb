require 'rails_helper'

describe Reply do
  include TranslationHelpers
  include MessagingHelpers
  include PhoneCallHelpers::TwilioHelpers
  include AnalyzableExamples
  include EnvHelpers

  let(:user) { build(:user) }

  # add more users here as you get more languages
  let(:local_users) do
    [create(:user, :cambodian, :from_unknown_operator), create(:user, :english), create(:user, :filipino)]
  end

  let(:new_reply) { build(:reply, :with_unset_destination, :user => user) }
  let(:partner) { build(:user, :with_name) }
  let(:reply) { create(:reply, :user => user) }
  let(:delivered_reply) { create(:reply, :delivered) }
  let(:reply_with_token) { create(:reply, :with_token) }

  def create_reply(*traits)
    options = traits.extract_options!

    with_token = true unless options.delete(:with_token) == false
    with_body = true unless options.delete(:with_body) == false
    delivered = true unless options.delete(:delivered) == false

    if delivered
      default_state = :queued_for_smsc_delivery
      options[:delivered_at] ||= 10.minutes.ago
    end

    state = options.delete(:state) || default_state

    args = [:reply, *traits]
    args << :delivered if delivered
    args << :with_token if with_token
    args << :with_no_body unless with_body
    args << state if state

    if with_body
      create(*args, options)
    else
      reply = build(*args, options)
      reply.save(:validate => false)
      reply
    end
  end

  def create_race_condition(reference_reply, state)
    Reply.where(:id => reference_reply.id).update_all(:state => state)
  end

  def assert_persisted_and_delivered(reply, mobile_number, options = {})
    options[:deliver] = true unless options[:deliver] == false
    expect(reply).to be_persisted
    expect(reply.destination).to eq(mobile_number)
    expect(reply.token).to eq(options[:token]) if options[:token]
    if options[:deliver]
      assertions = {:body => reply.body, :to => reply.destination}
      assertions.merge!(options.slice(:id, :suggested_channel, :via, :short_code, :smpp_server_id, :to, :body))
      assert_deliver(assertions)
      expect(reply).to be_delivered
      expect(reply).to be_queued_for_smsc_delivery
    else
      expect(reply).not_to be_delivered
      expect(reply).to be_pending_delivery
    end
  end

  def assert_reply(method, key, options = {})
    options[:args] ||= []
    options[:interpolations] || []
    (options[:test_users] || local_users).each do |local_user|
      reply = build(:reply, :user => local_user)
      expect_message { reply.send(method, *options[:args]) }
      asserted_reply = spec_translate(key, local_user.locale, *options[:interpolations])
      if options[:approx]
        expect(reply.body).to match(/#{asserted_reply}/)
      else
        expect(reply.body).to eq(asserted_reply)
      end

      assert_persisted_and_delivered(reply, local_user.mobile_number, options)
    end
  end

  describe "factory" do
    it "should be valid" do
      expect(new_reply).to be_valid
    end
  end

  describe "default state" do
    it "should be pending_delivery" do
      expect(reply).to be_pending_delivery
    end
  end

  it_should_behave_like "communicable" do
    let(:communicable_resource) { reply }
  end

  it_should_behave_like "chatable" do
    let(:chatable_resource) { reply }
  end

  it_should_behave_like "analyzable" do
    let(:group_by_column) { :created_at }

    def create_resource(*args)
      create(:reply, *args)
    end
  end

  it "should not be valid without a destination" do
    user.mobile_number = nil
    expect(new_reply).not_to be_valid
  end

  it "should not be valid with a duplicate a token" do
    new_reply.token = reply_with_token.token
    expect(new_reply).not_to be_valid
  end

  it "should not be valid without a body" do
    expect(build(:reply, :with_no_body)).not_to be_valid
  end

  describe "callbacks" do
    describe "before_validation(:on => :create)" do
      context "if the destination is nil" do
        it "should be set as the user's mobile number" do
          expect(new_reply).to be_valid
          expect(new_reply.destination).to eq(user.mobile_number)
        end
      end

      context "if the destination is set" do
        before do
          new_reply.destination = "1234"
        end

        it "should not be set as the user's mobile number" do
          expect(new_reply).to be_valid
          expect(new_reply.destination).to eq("1234")
        end
      end
    end
  end

  describe ".undelivered" do
    let(:another_reply) { create(:reply) }

    before do
      reply
      another_reply
      delivered_reply
    end

    it "should return only the undelivered replies" do
      expect(subject.class.undelivered).to eq([reply, another_reply])
    end
  end

  describe ".delivered" do
    before do
      reply
      delivered_reply
    end

    it "should return only the delivered replies" do
      expect(subject.class.delivered).to eq([delivered_reply])
    end
  end

  describe ".last_delivered" do
    let(:another_delivered_reply) { create(:reply, :delivered) }

    before do
      delivered_reply
      another_delivered_reply
      reply
    end

    it "should return the last delivered reply" do
      expect(subject.class.last_delivered).to eq(another_delivered_reply)
    end
  end

  describe ".cleanup!" do
    let(:time_considered_old) { 1.month.ago }

    def create_old_reply(*args)
      options = args.extract_options!
      create(:reply, *args, {:created_at => time_considered_old, :updated_at => time_considered_old}.merge(options))
    end

    let(:old_undelivered_reply) { create_old_reply }
    let(:old_delivered_reply) { create_old_reply(:delivered) }
    let(:new_undelivered_reply) { create(:reply) }
    let(:new_delivered_reply) { create(:reply, :delivered) }

    before do
      old_undelivered_reply
      old_delivered_reply
      new_undelivered_reply
      new_delivered_reply
    end

    it "should remove any delivered replies that are older than 1 month" do
      subject.class.cleanup!
      expect(Reply.all).to match_array([
        old_undelivered_reply, new_undelivered_reply, new_delivered_reply
      ])
    end
  end

  describe "#body" do
    it "should return an empty string if it is nil" do
      subject.body = nil
      expect(subject.body).to eq("")
    end
  end

  describe "#destination" do
    it "should be an alias for the attribute '#to'" do
      subject.destination = "123"
      expect(subject.to).to eq("123")

      subject.to = "456"
      expect(subject.destination).to eq("456")
    end
  end

  describe "#delivered?" do
    it "should return true if the message has been delivered" do
      expect(reply).not_to be_delivered
      expect_message { reply.deliver! }
      expect(reply).to be_delivered
    end
  end

  describe "#update_delivery_state(options = {})" do
    it "should correctly update the delivery state" do
      reply = create(:reply)
      reply.update_delivery_state
      expect(reply).to be_queued_for_smsc_delivery

      # tests the case where the delivery receipt
      # is received before the reply has been updated to 'queued_for_smsc_delivery'
      reply = create(:reply)
      reply.update_delivery_state(:state => "delivered")
      expect(reply).to be_delivered_by_smsc

      # tests that not passing :force => true will not update incase of a race condition
      reply = create(:reply)
      allow(reply).to receive(:update_delivery_state) do |options|
        options ||= {}
        create_race_condition(reply, :delivered_by_smsc)
        reply.instance_variable_set(:@delivery_state, options[:state])
        reply.instance_variable_set(:@force_state_update, options[:force])
        reply.update_delivery_status
        reply.send(:save_with_state_check)
      end

      reply.update_delivery_state
      expect(reply.reload).to be_delivered_by_smsc

      reply = create(:reply, :queued_for_smsc_delivery)
      reply.update_delivery_state(:state => "delivered")
      expect(reply).to be_delivered_by_smsc

      reply = create(:reply, :queued_for_smsc_delivery)
      reply.update_delivery_state(:state => "confirmed")
      expect(reply).to be_confirmed

      reply = create(:reply, :queued_for_smsc_delivery)
      reply.update_delivery_state(:state => "failed")
      expect(reply).to be_rejected

      reply = create(:reply, :queued_for_smsc_delivery)
      reply.update_delivery_state(:state => "error")
      expect(reply).to be_errored

      reply = create(:reply, :delivered_by_smsc)
      reply.update_delivery_state(:state => "confirmed")
      expect(reply).to be_confirmed

      reply = create(:reply, :delivered_by_smsc)
      reply.update_delivery_state(:state => "failed")
      expect(reply).to be_failed

      # tests the case where the delivery receipt
      # is received before the reply has been updated to 'queued_for_smsc_delivery'
      reply = create(:reply, :delivered_by_smsc)
      reply.update_delivery_state
      expect(reply).to be_delivered_by_smsc

      # tests that passing :force => true
      # updates regardless of a race condition
      reply = create(:reply)
      allow(reply).to receive(:update_delivery_state) do |options|
        options ||= {}
        create_race_condition(reply, :queued_for_smsc_delivery)
        reply.instance_variable_set(:@delivery_state, options[:state])
        reply.instance_variable_set(:@force_state_update, options[:force])
        reply.update_delivery_status
        reply.send(:save_with_state_check)
      end

      reply.update_delivery_state(:state => "delivered", :force => true)
      expect(reply.reload).to be_delivered_by_smsc

      reply = create(:reply, :failed)
      reply.update_delivery_state(:state => "delivered")

      expect(reply).to be_failed

      reply = create(:reply, :rejected)
      reply.update_delivery_state(:state => "confirmed")
      expect(reply).to be_confirmed

      reply = create(:reply, :rejected)
      reply.update_delivery_state(:state => "delivered")
      expect(reply).to be_failed

      reply = create(:reply, :failed)
      reply.update_delivery_state(:state => "confirmed")
      expect(reply).to be_confirmed

      reply = create(:reply, :confirmed)
      reply.update_delivery_state(:state => "delivered")
      expect(reply).to be_confirmed

      reply = create(:reply, :confirmed)
      reply.update_delivery_state(:state => "failed")
      expect(reply).to be_confirmed
    end

    context "the reply failed to deliver" do
      let(:user) { create(:user) }
      let(:reply) { create(:reply, :queued_for_smsc_delivery, :user => user) }

      before do
        create_list(:reply, previous_consecutive_failed_replies, :failed, :user => user)
        reply.update_delivery_state(:state => "failed")
      end

      context "and this also happened the last 4 times for this number" do
      let(:previous_consecutive_failed_replies) { 4 }
        it "should logout the intended recipient" do
          expect(user).not_to be_online
        end
      end

      context "and this also happened the last 3 times for this number" do
        let(:previous_consecutive_failed_replies) { 3 }
        it "should not yet logout the recipient" do
          expect(user).to be_online
          another_reply = create(:reply, :delivered_by_smsc, :user => user)
          another_reply.update_delivery_state(:state => "failed")
          expect(user).not_to be_online
        end
      end
    end
  end

  describe "#fetch_twilio_message_status!" do
    it "should do something" do
      twilio_message_states.each do |twilio_message_state, assertions|
        clear_enqueued_jobs
        subject = create(:reply, :delivered_by_twilio, :queued_for_smsc_delivery)
        expect_twilio_message_status_fetch(
          :message_sid => subject.token,
          :status => twilio_message_state
        ) { subject.fetch_twilio_message_status! }
        assert_twilio_message_status_fetched!(:message_sid => subject.token)
        subject.reload
        expect(subject.smsc_message_status).to eq(twilio_message_state)
        expect(subject.state).to eq(assertions[:reply_state])
        job = enqueued_jobs.last
        if assertions[:reschedule_job]
          assert_fetch_twilio_message_status_job_enqueued!(job, :id => subject.id)
        else
          expect(enqueued_jobs).to be_empty
        end
      end
    end
  end

  describe "#deliver!" do
    include MobilePhoneHelpers

    def default_smpp_server_id
      :twilio
    end

    context "by default" do
      before do
        stub_env(:deliver_via_nuntium => "0")
      end

      it "should enqueue a MT message to be sent via SMPP" do
        with_operators do |number_parts, assertions|
          number = number_parts.join
          reply = create(:reply, :to => number)
          message_sid = generate(:token)
          expect_delivery_via_twilio(:message_sid => message_sid) { reply.deliver! }
          reply.reload
          expect(reply.operator_name).to eq(assertions["id"])
          expect(reply.delivery_channel).to eq(assertions["smpp_server_id"] ? "smsc" : "twilio")
          assert_persisted_and_delivered(
            reply,
            number,
            :id => reply.id,
            :short_code => assertions["short_code"],
            :smpp_server_id => assertions["smpp_server_id"],
            :via => assertions["smpp_server_id"] || default_smpp_server_id
          )
        end
      end
    end

    context "via Twilio" do
      include TwilioHelpers

      before do
        stub_env(:deliver_via_nuntium => "0")
      end

      let(:dest_address) { "85589481811" }
      let(:body) { "test from twilio" }
      let(:message_sid) { generate(:guid) }

      subject { create(:reply, :to => dest_address, :body => body) }

      it "should send the reply via Twilio" do
        expect_delivery_via_twilio(:message_sid => message_sid) { subject.deliver! }
        assert_persisted_and_delivered(
          subject,
          dest_address,
          :id => subject.id,
          :via => :twilio,
        )
        expect(subject.token).to eq(message_sid)
        expect(subject.delivery_channel).to eq("twilio")
      end
    end

    context "via Nuntium" do
      def assert_persisted_and_delivered(reply, mobile_number, options = {})
        reply.reload
        expect(reply.operator_name).to eq(options[:operator_id]) if options[:operator_id]
        expect(reply.delivery_channel).to eq("nuntium")
        super(reply, mobile_number, options.merge(:via => :nuntium))
      end

      before do
        stub_env(:deliver_via_nuntium => "1")
      end

      it "should deliver the message and save the token" do
        expect_delivery_via_nuntium(:token => "token") { reply.deliver! }
        assert_persisted_and_delivered(reply, user.mobile_number, :token => "token")
      end

      it "should suggest the correct channel" do
        with_operators do |number_parts, assertions|
          number = number_parts.join
          reply = create(:reply, :to => number)
          expect_message { reply.deliver! }
          assert_persisted_and_delivered(
            reply,
            number,
            :suggested_channel => assertions["nuntium_channel"],
            :operator_id => assertions["id"]
          )
        end
        user = create(:user, :from_unknown_operator)
        reply = create(:reply, :user => user)
        expect_message { reply.deliver! }
        assert_persisted_and_delivered(
          reply,
          reply.destination,
          :suggested_channel => "twilio"
        )
      end

      context "given the delivery fails" do
        before do
          allow(Nuntium).to receive(:new).and_raise("BOOM! Cannot connect to Nuntium Server")
        end

        it "should not mark the reply as delivered" do
          expect { reply.deliver! }.to raise_error
          expect(reply).not_to be_delivered
          expect(reply).to be_pending_delivery
        end
      end

      context "given there is a race condition for when the state is updated" do
        before do
          allow(reply).to receive(:touch).with(:delivered_at) do
            reply.update_attribute(:delivered_at, Time.current)
            create_race_condition(reply, :delivered_by_smsc)
          end
        end

        it "should correctly update the state of the reply" do
          expect_message { reply.deliver! }
          expect(reply.reload).to be_delivered
          expect(reply).to be_delivered_by_smsc
        end
      end
    end
  end

  describe "#contact_me(from)" do
    it "should ask the recipient to sms and/or call back to contactable number" do
      assert_reply(
        :contact_me, :contact_me, :approx => true, :deliver => false,
        :args => [partner], :interpolations => [partner.screen_id, Regexp.escape(twilio_number)]
      )
    end
  end

  describe "#not_enough_credit!" do
    it "should tell the recipient that they don't have enough credit" do
      assert_reply(:not_enough_credit!, :not_enough_credit)
    end
  end

  describe "#follow_up!(from, options)" do
    it "should send canned follow up message to the recipient from the given user" do
      assert_reply(
        :follow_up!, :forward_message_approx, :approx => true,
        :args => [partner, {:to => :caller, :after => :conversation}], :interpolations => [partner.screen_id]
      )
    end
  end

  describe "#send_reminder!" do
    it "should send the user a reminder on how to use the service" do
      assert_reply(
        :send_reminder!, :anonymous_reminder, :approx => true,
        :args => [], :test_users => [local_users, create(:user, :gay), create(:user, :lesbian)].flatten
      )
    end
  end

  describe "#forward_message" do
    it "should show the message in a chat context but not deliver the message" do
      assert_reply(
        :forward_message, :forward_message,
        :args => [partner, "#{partner.screen_id}: hi how r u doing"], :interpolations => [partner.screen_id, "hi how r u doing"],
        :deliver => false
      )
    end
  end

  describe "#forward_message!" do
    it "should deliver the forwarded message" do
      assert_reply(
        :forward_message!, :forward_message,
        :args => [partner, "#{partner.screen_id.downcase}  :  hi how r u doing"], :interpolations => [partner.screen_id, "hi how r u doing"]
      )
    end
  end

  describe "#introduce!" do
    it "should imitate the user by sending a fake greeting to the new chat partner" do
      assert_reply(
        :introduce!, :forward_message_approx,
        :args => [partner], :interpolations => [partner.screen_id],
        :approx => true
      )
    end

    context "for gay recipients" do
      let(:partner) { create(:user, :gay) }

      it "should send a gay introduction" do
        assert_reply(
          :introduce!, :forward_message_approx,
          :args => [partner], :interpolations => [partner.screen_id],
          :test_users => [create(:user, :gay), create(:user, :lesbian)].flatten,
          :approx => true
        )
      end
    end
  end
end
