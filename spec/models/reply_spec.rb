require 'rails_helper'

describe Reply do
  include TranslationHelpers
  include MessagingHelpers
  include PhoneCallHelpers::TwilioHelpers
  include AnalyzableExamples

  let(:user) { build(:user) }

  # add more users here as you get more languages
  let(:local_users) do
    [create(:user, :cambodian, :from_unknown_operator), create(:user, :english), create(:user, :filipino)]
  end

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

  def assert_persisted_and_delivered(reply, mobile_number, options = {})
    options[:deliver] = true unless options[:deliver] == false
    expect(reply).to be_persisted
    expect(reply.destination).to eq(mobile_number)
    expect(reply.token).to eq(options[:token]) if options[:token]
    if options[:deliver]
      assertions = {:body => reply.body, :to => reply.destination}
      assertions.merge!(options.slice(:id, :suggested_channel, :via, :short_code, :smpp_server_id, :to, :body, :assertion_type))
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
      reply.send(method, *options[:args])
      asserted_reply = spec_translate(key, local_user.locale, *options[:interpolations])
      if options[:approx]
        expect(reply.body).to match(/#{asserted_reply}/)
      else
        expect(reply.body).to eq(asserted_reply)
      end

      assert_persisted_and_delivered(reply, local_user.mobile_number, options)
    end
  end

  describe "default state" do
    it "should be pending_delivery" do
      expect(reply).to be_pending_delivery
    end
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

  describe "associations" do
    it { is_expected.to belong_to(:msisdn_discovery) }
    it { is_expected.to belong_to(:user).touch(:last_contacted_at) }

    describe "user" do
      subject { create(:reply, :for_user) }

      it "should record touch the user's last_contacted_at" do
        user_timestamp = subject.user.updated_at
        subject.touch
        expect(subject.user.updated_at).to be > user_timestamp
        expect(subject.user.last_contacted_at).to be > user_timestamp
      end
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:to) }
    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_inclusion_of(:delivery_channel).in_array(["twilio", "smsc"]) }
  end

  describe "callbacks" do
    describe "after_commit" do
      context "reply belongs to a msisdn_discovery" do
        let(:msisdn_discovery) { create(:msisdn_discovery) }

        subject { build(:reply, :msisdn_discovery => msisdn_discovery) }

        it "should notify the msisdn_discovery" do
          expect(msisdn_discovery).to receive(:notify)
          subject.save!
        end
      end
    end

    describe "before_validation" do
      before do
        subject.valid?
      end

      describe "#normalize_token" do
        def create_reply(*args)
          options = args.extract_options!
          create(:reply, *args, {:token => token}.merge(options))
        end

        context "the token is nil" do
          let(:token) { nil }
          subject { create_reply }

          it { expect(subject.token).to eq(nil) }
        end

        context "token is present" do
          let(:token) { "ABC" }

          context "delivery channel is twilio" do
            subject { create_reply(:twilio_channel) }
            it { expect(subject.token).to eq(token) }
          end

          context "delivery channel is smsc" do
            subject { create_reply(:smsc_channel) }
            it { expect(subject.token).to eq("abc") }
          end
        end
      end

      describe ":on => :create" do
        let(:user) { create(:user, :from_registered_service_provider) }

        describe "#set_destination" do
          context "the destination is nil" do
            subject { build(:reply, :user => user) }

            it { expect(subject.destination).to eq(user.mobile_number) }
            it { expect(subject.operator_name).to be_present }
          end

          context "the destination is present" do
            let(:destination) { generate(:unknown_operator_number) }

            subject { build(:reply, :destination => destination, :user => user) }
            it { expect(subject.destination).to eq(destination) }
            it { expect(subject.operator_name).not_to be_present }
          end
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

  describe ".token_find!(token)" do
    let(:reply) { create(:reply, :token => "abc") }

    context "given the reply exists" do
      before do
        reply
      end

      it { expect(described_class.token_find!("ABC")).to eq(reply) }
    end

    context "given the reply does not exist" do
      it { expect { described_class.token_find!("ABC") }.to raise_error(ActiveRecord::RecordNotFound) }
    end
  end

  describe ".accepted_by_smsc" do
    before do
      create(:reply, :pending_delivery, :delivered)

      Reply.aasm.states.each do |state|
        create(:reply, state.name)
      end
    end

    it { expect(described_class.accepted_by_smsc.pluck(:state)).not_to include("pending_delivery", "queued_for_smsc_delivery") }
  end

  describe ".not_a_msisdn_discovery" do
    let(:reply_for_user) { create(:reply, :for_user) }

    before do
      reply_for_user
      create(:reply, :for_msisdn_discovery)
    end

    it { expect(described_class.not_a_msisdn_discovery).to match_array([reply_for_user]) }
  end

  describe ".fix_invalid_states!" do
    let(:undelivered) do
      reply = create_reply(:queued_for_smsc_delivery)
      reply.update_column(:delivered_at, nil)
      reply
    end

    let(:queued_for_smsc_delivery_too_long_with_token) do
      create(:reply, :foo_bar, :with_token, :smsc_channel)
    end

    let(:queued_for_smsc_delivery_with_token) do
      create(:reply, :queued_for_smsc_delivery, :with_token)
    end

    before do
      expect(undelivered).not_to be_delivered
      expect(queued_for_smsc_delivery_too_long_with_token).to be_queued_for_smsc_delivery
      expect(queued_for_smsc_delivery_with_token).to be_queued_for_smsc_delivery
      described_class.fix_invalid_states!
    end

    it { expect(undelivered.reload).to be_delivered }
    it { expect(queued_for_smsc_delivery_too_long_with_token.reload).not_to be_queued_for_smsc_delivery }
    it { expect(queued_for_smsc_delivery_with_token.reload).to be_queued_for_smsc_delivery }
  end

  describe ".failed_to_deliver" do
    let(:failed_reply) { create(:reply, :failed) }
    let(:expired_reply) { create(:reply, :expired) }
    let(:results) { describ }

    before do
      failed_reply
      expired_reply
      create(:reply, :delivered)
      create(:reply, :confirmed)
      create(:reply, :unknown)
      create(:reply, :errored)
    end

    it { expect(described_class.failed_to_deliver).to match_array([failed_reply, expired_reply]) }
  end

  describe "handling failed messages" do
    def create_user(*args)
      options = args.extract_options!
      create(:user, :without_recent_interaction, *args, options)
    end

    def create_reply(*args)
      options = args.extract_options!
      create(:reply, :failed, *args, {:user => user}.merge(options))
    end

    let(:num_failed_replies) { 4 }
    let(:results) { described_class.to_users_that_cannot_be_contacted }

    before do
      num_failed_replies.times do
        create_reply
      end
    end

    context "for users that cannot be contacted" do
      describe ".to_users_that_cannot_be_contacted" do
        it { expect(results[0].user).to eq(user) }
      end

      describe ".handle_failed" do
        let(:job) { enqueued_jobs.last }

        before do
          described_class.handle_failed!
        end

        it "should enqueue a job to cleanup the user" do
          expect(job[:job]).to eq(UserCleanupJob)
          expect(job[:args][0]).to eq(user.id)
        end
      end
    end

    describe ".to_users_that_cannot_be_contacted" do
      context "for offline users" do
        let(:user) { create_user(:offline) }

        it { expect(results).to be_empty }
      end

      context "for online users" do
        context "with recent interaction" do
          let(:user) { create_user(:with_recent_interaction) }
          it { expect(results).to be_empty }
        end

        context "without recent interaction" do
          context "with not enough failed replies" do
            let(:num_failed_replies) { 3 }
            it { expect(results).to be_empty }
          end
        end
      end
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
      reply.deliver!
      expect(reply).to be_delivered
    end
  end

  describe "#delivered_by_twilio!" do
    let(:subject) { create(:reply, :queued_for_smsc_delivery, :twilio_channel, :with_token) }

    before do
      subject.delivered_by_twilio!
    end

    it { expect(subject).to be_delivered_by_smsc }
  end

  describe "#delivery_status_updated_by_smsc!(smsc_name, status)" do
    it "should correctly update the state" do
      smsc_message_states.each do |smsc_message_state, assertions|
        subject = create(:reply, :smsc_channel, :delivered_by_smsc, :with_token)
        subject.delivery_status_updated_by_smsc!("SMART", smsc_message_state)
        expect(subject.smsc_message_status).to eq(smsc_message_state.downcase)
        expect(subject.state).to eq(assertions[:reply_state])
      end
    end
  end

  describe "#delivered_by_smsc!(smsc_name, smsc_message_id, successful, error_message = nil)" do
    let(:subject) { create(:reply, :queued_for_smsc_delivery, :smsc_channel) }
    let(:smsc_name) { "SMART" }
    let(:smsc_message_id) { "7869576120333847249" }

    def do_delivered_by_smsc!
      subject.delivered_by_smsc!(smsc_name, smsc_message_id, successful, error_message)
      subject.reload
    end

    before do
      do_delivered_by_smsc!
    end

    context "where the delivery was successful" do
      let(:successful) { true }
      let(:error_message) { nil }

      it "should update the message_token, smsc_message_status and state" do
        expect(subject.token).to eq(smsc_message_id)
        expect(subject.smsc_message_status).to eq(error_message)
        expect(subject).to be_delivered_by_smsc
      end
    end

    context "where the status was not successful" do
      let(:successful) { false }
      let(:error_message) { "Dest address invalid" }

      it "should update the smsc_message_status and state" do
        expect(subject.token).to eq(nil)
        expect(subject.smsc_message_status).to eq("dest_address_invalid")
        expect(subject).to be_failed
      end
    end
  end

  describe "#fetch_twilio_message_status!" do
    it "should update the message state from Twilio" do
      twilio_message_states.each do |twilio_message_state, assertions|
        clear_enqueued_jobs
        subject = create(:reply, :twilio_channel, :twilio_delivered_by_smsc)
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

    def expect_delivery_via_twilio(options = {}, &block)
      VCR.use_cassette(twilio_post_messages_cassette, :erb => twilio_post_messages_erb(options)) do
        trigger_job(:only => [TwilioMtMessageSenderJob]) { yield }
      end
    end

    def default_smpp_server_id
      :twilio
    end

    context "by default" do
      context "where there is no destination" do
        it "should not deliver message" do
          subject.deliver!
          expect(subject).to be_pending_delivery
        end
      end

      it "should enqueue a MT message to be sent via SMPP" do
        with_operators do |number_parts, assertions|
          clear_enqueued_jobs
          number = number_parts.join
          reply = build(:reply, :to => number)
          message_sid = generate(:smsc_token)
          expect_delivery_via_twilio(:message_sid => message_sid) { reply.deliver! }
          reply.reload
          expect(reply.operator_name).to eq(assertions["id"])
          expect(reply.delivery_channel).to eq(assertions["smpp_server_id"] ? "smsc" : "twilio")
          expect(reply.smpp_server_id).to eq(assertions["smpp_server_id"])
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

      let(:dest_address) { "85589481811" }
      let(:body) { "test from twilio" }
      let(:message_sid) { generate(:guid) }

      subject { build(:reply, :to => dest_address, :body => body) }

      it "should send the reply via Twilio" do
        expect_delivery_via_twilio(:message_sid => message_sid) { subject.deliver! }
        assert_persisted_and_delivered(
          subject,
          dest_address,
          :id => subject.id,
          :via => :twilio,
          :assertion_type => :request
        )
        subject.reload
        expect(subject.token).to eq(message_sid)
        expect(subject.delivery_channel).to eq("twilio")
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

  describe "#send_reminder!(options = {})" do
    subject { build(:reply) }

    it "should send the user a reminder on how to use the service" do
      assert_reply(
        :send_reminder!, :anonymous_reminder, :approx => true,
        :args => [], :test_users => [local_users, create(:user, :gay), create(:user, :lesbian)].flatten
      )
    end

    it "should set #smsc_priority to -5" do
      subject.send_reminder!
      expect(subject.smsc_priority).to eq(-5)
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

  describe "#forward_message!(from, message, options = {})" do
    subject { build(:reply) }

    it "should deliver the forwarded message" do
      assert_reply(
        :forward_message!, :forward_message,
        :args => [partner, "#{partner.screen_id.downcase}  :  hi how r u doing"], :interpolations => [partner.screen_id, "hi how r u doing"]
      )
    end

    it "should set #smsc_priority to 10" do
      subject.forward_message!(partner, "foo")
      expect(subject.smsc_priority).to eq(10)
    end
  end

  describe "#broadcast!(options = {})" do
    subject { build(:reply) }
    let(:args) { [{ :locale => "kh" }] }

    it "should send a broadcast message" do
      assert_reply(:broadcast!, :broadcast, :args => args, :test_users => [create(:user, :cambodian)])
    end

    it "should set #smsc_priority to -10" do
      subject.broadcast!(*args)
      expect(subject.smsc_priority).to eq(-10)
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
