require 'spec_helper'

describe Reply do
  include TranslationHelpers
  include MessagingHelpers
  include ResqueHelpers

  let(:user) { build(:user) }

  # add more users here as you get more languages
  let(:local_users) do
    [create(:user, :cambodian), create(:user, :english)]
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
    Reply.update_all({:state => state}, :id => reference_reply.id)
  end

  def assert_persisted_and_delivered(reply, mobile_number, options = {})
    options[:deliver] = true unless options[:deliver] == false
    reply.should be_persisted
    reply.destination.should == mobile_number
    reply.token.should == options[:token] if options[:token]
    if options[:deliver]
      assertions = {:body => reply.body, :to => reply.destination}
      assertions.merge!(options.slice(:id, :suggested_channel, :via, :short_code, :mt_message_queue))
      assert_deliver(assertions)
      reply.should be_delivered
      reply.should be_queued_for_smsc_delivery
    else
      reply.should_not be_delivered
      reply.should be_pending_delivery
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
        reply.body.should =~ /#{asserted_reply}/
      else
        reply.body.should == asserted_reply
      end

      assert_persisted_and_delivered(reply, local_user.mobile_number, options)
    end
  end

  describe "factory" do
    it "should be valid" do
      new_reply.should be_valid
    end
  end

  describe "default state" do
    it "should be pending_delivery" do
      reply.should be_pending_delivery
    end
  end

  it_should_behave_like "communicable" do
    let(:communicable_resource) { reply }
  end

  it_should_behave_like "chatable" do
    let(:chatable_resource) { reply }
  end

  it_should_behave_like "analyzable"

  it "should not be valid without a destination" do
    user.mobile_number = nil
    new_reply.should_not be_valid
  end

  it "should not be valid with a duplicate a token" do
    new_reply.token = reply_with_token.token
    new_reply.should_not be_valid
  end

  it "should not be valid without a body" do
    build(:reply, :with_no_body).should_not be_valid
  end

  describe "callbacks" do
    describe "when saving the reply" do
      context "if the destination is nil" do
        it "should be set as the user's mobile number" do
          new_reply.should be_valid
          new_reply.destination.should == user.mobile_number
        end
      end

      context "if the destination is set" do
        before do
          new_reply.destination = 1234
        end

        it "should not be set as the user's mobile number" do
          new_reply.should be_valid
          new_reply.destination.should == 1234
        end
      end
    end
  end

  describe ".undelivered" do
    before do
      reply
      delivered_reply
    end

    it "should return only the undelivered replies" do
      subject.class.undelivered.should == [reply]
      subject.class.undelivered.order_values.should == [:created_at]
    end
  end

  describe ".delivered" do
    before do
      reply
      delivered_reply
    end

    it "should return only the delivered replies" do
      subject.class.delivered.should == [delivered_reply]
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
      subject.class.last_delivered.should == another_delivered_reply
    end
  end

  describe "querying ao messages from nuntium" do
    let(:recently_queued_reply) { create_reply(:delivered_at => Time.now) }
    let(:less_recently_queued_reply) { create_reply }
    let(:reply_with_no_token) { create_reply(:with_token => false) }
    let(:blank_reply) { create_reply(:with_body => false) }

    describe ".query_queued!" do
      let!(:smsc_delivered_reply) { create_reply(:state => :delivered_by_smsc) }
      let!(:confirmed_reply) { create_reply(:state => :confirmed) }

      before do
        recently_queued_reply
        less_recently_queued_reply
        reply_with_no_token
        blank_reply
      end

      it "should update the message state based off of the nuntium ao state" do
        expect_ao_fetch(:token => less_recently_queued_reply.token) do
          do_background_task { subject.class.query_queued! }
        end

        recently_queued_reply.reload.should be_queued_for_smsc_delivery
        reply_with_no_token.reload.should be_queued_for_smsc_delivery
        blank_reply.reload.should be_queued_for_smsc_delivery
        smsc_delivered_reply.reload.should be_delivered_by_smsc
        confirmed_reply.reload.should be_confirmed
        less_recently_queued_reply.reload.should be_delivered_by_smsc
      end
    end

    describe "#query_nuntium_ao!" do
      it "should update the state based off of the nuntium ao state" do
        reply_with_no_token.query_nuntium_ao!
        reply_with_no_token.reload.should be_queued_for_smsc_delivery
        reply_with_no_token.should be_delivered

        blank_reply.query_nuntium_ao!
        blank_reply.reload.should be_queued_for_smsc_delivery
        blank_reply.should be_delivered

        expect_ao_fetch(:token => less_recently_queued_reply.token, :body => "") do
          less_recently_queued_reply.query_nuntium_ao!
        end

        # assert that the reply is marked undelivered for a blank ao body
        less_recently_queued_reply.should_not be_delivered

        expect_ao_fetch(:token => recently_queued_reply.token, :state => "confirmed") do
          recently_queued_reply.query_nuntium_ao!
        end

        recently_queued_reply.reload.should be_confirmed
        recently_queued_reply.should be_delivered
      end
    end
  end

  describe "undelivering blank replies" do
    let(:chat_with_message) { create(:chat, :with_message) }
    let(:chat) { create(:chat) }

    let(:blank_reply_from_chat_with_messages) { create_reply }
    let(:blank_reply_from_chat_with_no_messages) { create_reply(:chat => chat) }
    let(:blank_reply_no_chat) { create_reply(:from_chat => false) }
    let(:blank_reply_without_token) { create_reply(:with_token => false) }
    let(:reply_with_body) { create_reply(:with_body => true) }

    def create_reply(*traits)
      options = traits.extract_options!
      from_chat = true unless options.delete(:from_chat) == false
      options[:with_body] = false unless options[:with_body]

      default_chat = chat_with_message if from_chat
      options[:chat] ||= default_chat

      args = []
      args << :from_chat_initiator if from_chat
      super(*args, options)
    end

    def assert_fixed(reference_reply)
      reference_reply.reload.body.should be_present
      reference_reply.should_not be_delivered
      reference_reply.chat.should_not be_active
    end

    def assert_not_fixed(reference_reply)
      old_reply_body = reference_reply.body
      reference_reply.should be_delivered
      reference_reply.body.should == old_reply_body
    end

    describe ".fix_blank!" do
      before do
        blank_reply_from_chat_with_messages
        blank_reply_from_chat_with_no_messages
        blank_reply_no_chat
        blank_reply_without_token
        reply_with_body
      end

      it "should fix delivered blank messages and mark them as undelivered" do
        do_background_task do
          expect_message do
            subject.class.fix_blank!
          end
        end

        assert_fixed(blank_reply_from_chat_with_messages)
        assert_not_fixed(blank_reply_from_chat_with_no_messages)
        assert_not_fixed(blank_reply_no_chat)
        assert_not_fixed(blank_reply_without_token)
        assert_not_fixed(reply_with_body)
      end
    end

    describe "#fix_blank!" do
      it "should only redeliver blank messages that were intended for forwarding" do
        # create a reply and a message in the chat
        create_reply(:with_body => true)
        # create a blank reply
        blank_reply_from_chat_with_messages
        # create a second message with a body
        create(:message, :from_chat_initiator, :body => "foo", :chat => chat_with_message)
        expect_message { blank_reply_from_chat_with_messages.fix_blank! }

        assert_fixed(blank_reply_from_chat_with_messages)

        # assert that the blank reply does not contain the content of the second message
        blank_reply_from_chat_with_messages.body.should_not include("foo")

        blank_reply_from_chat_with_no_messages.fix_blank!
        assert_not_fixed(blank_reply_from_chat_with_no_messages)

        blank_reply_no_chat.fix_blank!
        assert_not_fixed(blank_reply_no_chat)

        reply_with_body.fix_blank!
        assert_not_fixed(reply_with_body)
      end
    end
  end

  describe "#body" do
    it "should return an empty string if it is nil" do
      subject.body = nil
      subject.body.should == ""
    end
  end

  describe "#destination" do
    it "should be an alias for the attribute '#to'" do
      subject.destination = 123
      subject.to.should == 123

      subject.to = 456
      subject.destination.should == 456
    end
  end

  describe "#delivered?" do
    it "should return true if the message has been delivered" do
      reply.should_not be_delivered
      expect_message { reply.deliver! }
      reply.should be_delivered
    end
  end

  describe "#update_delivery_state(options = {})" do
    it "should correctly update the delivery state" do
      reply = create(:reply)
      reply.update_delivery_state
      reply.should be_queued_for_smsc_delivery

      # tests the case where the delivery receipt
      # is received before the reply has been updated to 'queued_for_smsc_delivery'
      reply = create(:reply)
      reply.update_delivery_state(:state => "delivered")
      reply.should be_delivered_by_smsc

      # tests that not passing :force => true will not update incase of a race condition
      reply = create(:reply)
      reply.stub(:update_delivery_state) do |options|
        options ||= {}
        create_race_condition(reply, :delivered_by_smsc)
        reply.instance_variable_set(:@delivery_state, options[:state])
        reply.instance_variable_set(:@force_state_update, options[:force])
        reply.update_delivery_status
      end
      reply.update_delivery_state
      reply.reload.should be_delivered_by_smsc

      reply = create(:reply, :queued_for_smsc_delivery)
      reply.update_delivery_state(:state => "delivered")
      reply.should be_delivered_by_smsc

      reply = create(:reply, :queued_for_smsc_delivery)
      reply.update_delivery_state(:state => "confirmed")
      reply.should be_confirmed

      reply = create(:reply, :queued_for_smsc_delivery)
      reply.update_delivery_state(:state => "failed")
      reply.should be_rejected

      reply = create(:reply, :delivered_by_smsc)
      reply.update_delivery_state(:state => "confirmed")
      reply.should be_confirmed

      reply = create(:reply, :delivered_by_smsc)
      reply.update_delivery_state(:state => "failed")
      reply.should be_failed

      # tests the case where the delivery receipt
      # is received before the reply has been updated to 'queued_for_smsc_delivery'
      reply = create(:reply, :delivered_by_smsc)
      reply.update_delivery_state
      reply.should be_delivered_by_smsc

      # tests that passing :force => true
      # updates regardless of a race condition
      reply = create(:reply)
      reply.stub(:update_delivery_state) do |options|
        options ||= {}
        create_race_condition(reply, :queued_for_smsc_delivery)
        reply.instance_variable_set(:@delivery_state, options[:state])
        reply.instance_variable_set(:@force_state_update, options[:force])
        reply.update_delivery_status
      end
      reply.update_delivery_state(:state => "delivered", :force => true)
      reply.reload.should be_delivered_by_smsc

      reply = create(:reply, :failed)
      reply.update_delivery_state(:state => "delivered")
      reply.should be_failed

      reply = create(:reply, :rejected)
      reply.update_delivery_state(:state => "confirmed")
      reply.should be_confirmed

      reply = create(:reply, :rejected)
      reply.update_delivery_state(:state => "delivered")
      reply.should be_failed

      reply = create(:reply, :failed)
      reply.update_delivery_state(:state => "confirmed")
      reply.should be_confirmed

      reply = create(:reply, :confirmed)
      reply.update_delivery_state(:state => "delivered")
      reply.should be_confirmed

      reply = create(:reply, :confirmed)
      reply.update_delivery_state(:state => "failed")
      reply.should be_confirmed
    end
  end

  describe "#deliver!" do
    include MobilePhoneHelpers

    context "without Nuntium" do
      before do
        ResqueSpec.reset!
      end

      it "should enqueue a MT message to be sent via SMPP" do
        with_operators do |number_parts, assertions|
          number = number_parts.join
          reply = create(:reply, :to => number)
          reply.deliver!
          assert_persisted_and_delivered(
            reply, number,
            :id => reply.token, :short_code => assertions["short_code"],
            :mt_message_queue => assertions["mt_message_queue"]
          )
        end
        reply = create(:reply)
        reply.deliver!
        assert_persisted_and_delivered(reply, reply.destination)
        reply.token.should be_present
      end
    end

    context "via Nuntium" do
      def assert_persisted_and_delivered(reply, mobile_number, options = {})
        super(reply, mobile_number, options.merge(:via => :nuntium))
      end

      before do
        ENV.stub(:[]).and_call_original
        ENV.stub(:[]).with("DELIVER_VIA_NUNTIUM").and_return("1")
      end

      it "should deliver the message and save the token" do
        expect_message(:token => "token") { reply.deliver! }
        assert_persisted_and_delivered(reply, user.mobile_number, :token => "token")
      end

      it "should suggest the correct channel" do
        with_operators do |number_parts, assertions|
          number = number_parts.join
          reply = create(:reply, :to => number)
          expect_message { reply.deliver! }
          assert_persisted_and_delivered(reply, number, :suggested_channel => assertions["nuntium_channel"])
        end
        reply = create(:reply)
        expect_message { reply.deliver! }
        assert_persisted_and_delivered(reply, reply.destination, :suggested_channel => "twilio")
      end

      context "given the delivery fails" do
        before do
          Nuntium.stub(:new).and_raise("BOOM! Cannot connect to Nuntium Server")
        end

        it "should not mark the reply as delivered" do
          expect { reply.deliver! }.to raise_error
          reply.should_not be_delivered
          reply.should be_pending_delivery
        end
      end

      context "given there is a race condition for when the state is updated" do
        before do
          reply.stub(:touch).with(:delivered_at) do
            reply.update_attribute(:delivered_at, Time.now)
            create_race_condition(reply, :delivered_by_smsc)
          end
        end

        it "should correctly update the state of the reply" do
          expect_message { reply.deliver! }
          reply.reload.should be_delivered
          reply.should be_delivered_by_smsc
        end
      end
    end
  end

  describe "#call_me(from, on)" do
    it "should ask the recipient to call back to the number given" do
      assert_reply(
        :call_me, :call_me, :approx => true, :deliver => false,
        :args => [partner, "2443"], :interpolations => [partner.screen_id, "2443"]
      )
    end
  end

  describe "#send_reminder!" do
    it "should send the user a reminder on how to use the service" do
      assert_reply(
        :send_reminder!, :anonymous_reminder, :approx => true,
        :args => []
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
  end
end
