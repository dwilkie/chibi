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

  describe "validations" do
    it { is_expected.to validate_presence_of(:to) }
    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_inclusion_of(:delivery_channel).in_array(["twilio", "smsc"]) }
    it { is_expected.to validate_uniqueness_of(:token) }
  end

  describe "callbacks" do
    describe "before_validation(:on => :create)" do
      let(:user) { create(:user, :from_registered_service_provider) }

      before do
        subject.valid?
      end

      context "if the destination is nil" do
        subject { build(:reply, :user => user) }

        it { expect(subject.destination).to eq(user.mobile_number) }
        it { expect(subject.operator_name).to be_present }
      end

      context "if the destination is set" do
        let(:destination) { generate(:unknown_operator_number) }

        subject { build(:reply, :destination => destination, :user => user) }
        it { expect(subject.destination).to eq(destination) }
        it { expect(subject.operator_name).not_to be_present }
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

  describe "#delivered_by_smsc!(smsc_name, smsc_message_id, status)" do
    let(:subject) { create(:reply, :queued_for_smsc_delivery, :smsc_channel) }
    let(:smsc_name) { "SMART" }
    let(:smsc_message_id) { "7869576120333847249" }

    def do_delivered_by_smsc!
      subject.delivered_by_smsc!(smsc_name, smsc_message_id, status)
      subject.reload
    end

    before do
      do_delivered_by_smsc!
    end

    context "where the delivery was successful" do
      let(:status) { true }

      it "should update the message token and status" do
        expect(subject.token).to eq(smsc_message_id)
        expect(subject).to be_delivered_by_smsc
      end
    end

    context "where the status was not successful" do
      let(:status) { false }
      let(:job) { enqueued_jobs.last }

      it "should enqueue a job to redeliver the message" do
        expect(job[:job]).to eq(MtMessageSenderJob)
        expect(job[:args][0]).to eq(subject.id)
      end
    end
  end

  describe "#fetch_twilio_message_status!" do
    it "should update the message state from Twilio" do
      twilio_message_states.each do |twilio_message_state, assertions|
        clear_enqueued_jobs
        subject = create(:reply, :twilio_channel, :delivered_by_smsc, :with_token)
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
          message_sid = generate(:token)
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
        )
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
