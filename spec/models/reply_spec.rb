require 'spec_helper'

describe Reply do
  include TranslationHelpers
  include MessagingHelpers

  let(:user) { build(:user) }

  # add more users here as you get more languages
  let(:local_users) do
    [build(:cambodian), build(:english)]
  end

  let(:new_reply) { build(:reply, :with_unset_destination, :user => user) }
  let(:partner) { build(:user_with_name) }
  let(:reply) { create(:reply, :user => user) }
  let(:delivered_reply) { create(:delivered_reply) }
  let(:reply_with_token) { create(:reply_with_token) }

  let(:recently_queued_reply) { create_reply(:delivered_at => Time.now) }
  let(:less_recently_queued_reply) { create_reply(:token => "token") }
  let(:reply_with_no_token) { create_reply(:with_token => false) }

  def create_reply(options = {})
    with_token = true unless options.delete(:with_token) == false
    state = options.delete(:state) || :queued_for_smsc_delivery
    options[:delivered_at] ||= 10.minutes.ago

    args = [:reply, :delivered]
    args << :with_token if with_token
    args << state
    create(*args, options)
  end

  def assert_persisted_and_delivered(reply, mobile_number, options = {})
    options[:deliver] = true unless options[:deliver] == false
    reply.should be_persisted
    reply.destination.should == mobile_number
    reply.token.should == options[:token] if options[:token]
    if options[:deliver]
      assert_deliver(:body => reply.body, :to => reply.destination)
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
      users_default_locale = local_user.country_code.to_sym
      {:en => users_default_locale, users_default_locale => :en}.each do |user_locale, alternate_locale|
        reply = subject.class.new
        local_user.locale = user_locale
        user_country_code = local_user.country_code
        reply.user = local_user
        expect_message { reply.send(method, *options[:args]) }
        asserted_reply = spec_translate(key, [user_locale, user_country_code], *options[:interpolations])
        if options[:approx]
          reply.body.should =~ /#{asserted_reply}/
        else
          reply.body.should == asserted_reply
        end

        if options[:no_alternate_translation]
          reply.locale.should be_nil
          reply.alternate_translation.should be_nil
        else
          reply.locale.should == local_user.locale
          asserted_alternate_translation = spec_translate(key, [alternate_locale, user_country_code], *options[:interpolations])
          if options[:approx]
            reply.alternate_translation.should =~ /#{asserted_alternate_translation}/
          else
            reply.alternate_translation.should == asserted_alternate_translation
          end
        end
        assert_persisted_and_delivered(reply, local_user.mobile_number, options)
      end
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
    let(:communicable_resource) { new_reply }
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
    let(:another_delivered_reply) { create(:delivered_reply) }

    before do
      delivered_reply
      another_delivered_reply
      reply
    end

    it "should return the last delivered reply" do
      subject.class.last_delivered.should == another_delivered_reply
    end
  end

  describe ".query_queued!" do
    include ResqueHelpers

    let!(:smsc_delivered_reply) { create_reply(:state => :delivered_by_smsc) }
    let!(:confirmed_reply) { create_reply(:state => :confirmed) }

    before do
      recently_queued_reply
      less_recently_queued_reply
      reply_with_no_token
    end

    it "should update the message state based off of the nuntium ao state" do
      do_background_task do
        expect_ao_fetch(:token => less_recently_queued_reply.token) do
          subject.class.query_queued!
        end
      end

      recently_queued_reply.reload.should be_queued_for_smsc_delivery
      reply_with_no_token.reload.should be_queued_for_smsc_delivery
      smsc_delivered_reply.reload.should be_delivered_by_smsc
      confirmed_reply.reload.should be_confirmed
      less_recently_queued_reply.reload.should be_delivered_by_smsc
    end
  end

  describe "#query_state!" do
    it "should update the state based off of the nuntium ao state" do
      reply_with_no_token.query_state!
      reply_with_no_token.reload.should be_queued_for_smsc_delivery

      expect_ao_fetch(:token => less_recently_queued_reply.token) do
        less_recently_queued_reply.query_state!
      end

      less_recently_queued_reply.reload.should be_delivered

      expect_ao_fetch(:token => recently_queued_reply.token, :state => "confirmed") do
        recently_queued_reply.query_state!
      end

      recently_queued_reply.reload.should be_confirmed
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

  describe "#locale" do
    it "should return a lowercase symbol of the locale if set" do
      subject.locale.should be_nil
      subject.locale = :EN
      subject.locale.should == :en
    end
  end

  describe "#delivered?" do
    it "should return true if the message has been delivered" do
      reply.should_not be_delivered
      expect_message { reply.deliver! }
      reply.should be_delivered
    end
  end

  describe "#update_delivery_state(state = nil)" do
    it "should correctly update the delivery state" do
      reply = create(:reply)
      reply.update_delivery_state
      reply.should be_queued_for_smsc_delivery

      # tests the case where the delivery receipt
      # is received before the reply has been updated to 'queued_for_smsc_delivery'
      reply = create(:reply)
      reply.update_delivery_state("delivered")
      reply.should be_delivered_by_smsc

      reply = create(:reply, :queued_for_smsc_delivery)
      reply.update_delivery_state("delivered")
      reply.should be_delivered_by_smsc

      reply = create(:reply, :queued_for_smsc_delivery)
      reply.update_delivery_state("confirmed")
      reply.should be_confirmed

      reply = create(:reply, :queued_for_smsc_delivery)
      reply.update_delivery_state("failed")
      reply.should be_rejected

      reply = create(:reply, :delivered_by_smsc)
      reply.update_delivery_state("confirmed")
      reply.should be_confirmed

      reply = create(:reply, :delivered_by_smsc)
      reply.update_delivery_state("failed")
      reply.should be_failed

      # tests the case where the delivery receipt
      # is received before the reply has been updated to 'queued_for_smsc_delivery'
      reply = create(:reply, :delivered_by_smsc)
      reply.update_delivery_state
      reply.should be_delivered_by_smsc

      reply = create(:reply, :failed)
      reply.update_delivery_state("delivered")
      reply.should be_failed

      reply = create(:reply, :rejected)
      reply.update_delivery_state("confirmed")
      reply.should be_confirmed

      reply = create(:reply, :rejected)
      reply.update_delivery_state("delivered")
      reply.should be_failed

      reply = create(:reply, :failed)
      reply.update_delivery_state("confirmed")
      reply.should be_confirmed

      reply = create(:reply, :confirmed)
      reply.update_delivery_state("delivered")
      reply.should be_confirmed

      reply = create(:reply, :confirmed)
      reply.update_delivery_state("failed")
      reply.should be_confirmed
    end
  end

  describe "#deliver!" do
    it "should deliver the message and save the token" do
      expect_message(:token => "token") { new_reply.deliver! }
      assert_persisted_and_delivered(new_reply, user.mobile_number, :token => "token")
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
      module RaceCondition
        def self.included(base)
          base.class_eval do
            alias_method_chain :perform_delivery!, :race_condition
          end
        end

        def perform_delivery_with_race_condition!(message)
          perform_delivery_without_race_condition!(message)
          Reply.update_all({:state => "delivered_by_smsc"}, :id => id)
        end
      end

      module NoRaceCondition
        def self.included(base)
          base.class_eval do
            target = :perform_delivery!
            feature = :race_condition

            # Strip out punctuation on predicates or bang methods since
            # e.g. target?_without_feature is not a valid method name.
            aliased_target, punctuation = target.to_s.sub(/([?!=])$/, ''), $1
            yield(aliased_target, punctuation) if block_given?

            with_method, without_method = "#{aliased_target}_with_#{feature}#{punctuation}", "#{aliased_target}_without_#{feature}#{punctuation}"

            alias_method target, without_method

            case
            when public_method_defined?(without_method)
              public target
            when protected_method_defined?(without_method)
              protected target
            when private_method_defined?(without_method)
              private target
            end
          end
        end
      end

      before do
        Reply.send(:include, RaceCondition)
      end

      after do
        Reply.send(:include, NoRaceCondition)
      end

      it "should correctly update the state of the reply" do
        expect_message { reply.deliver! }
        reply.reload.should be_delivered
        reply.should be_delivered_by_smsc
      end
    end
  end

  describe "#deliver_alternate_translation!" do
    def assert_deliver_alternate_translation(factory_name, options = {})
      deliver = options.delete(:deliver)
      reply = build(factory_name, options)

      if deliver
        expect_message { reply.deliver_alternate_translation! }
        assert_deliver(:body => reply.send(deliver))
      else
        # will raise an error if it delivers because the message is not expected
        reply.deliver_alternate_translation!
      end
    end

    it "should deliver the alternate translation based off the users locale if available" do
      # assert no deliver for reply without alternate translation
      assert_deliver_alternate_translation(:delivered_reply)

      # assert no delivery for a reply with an alternate translation but no locale
      assert_deliver_alternate_translation(:delivered_reply_with_alternate_translation_no_locale)

      # assert no delivery for a reply with an alternate translation that has not been delivered yet
      assert_deliver_alternate_translation(:reply_with_alternate_translation)

      # assert delivery of the body for a delivered reply with an alternate translation
      # when the user's locale is the same as the original delivered reply
      assert_deliver_alternate_translation(:delivered_reply_with_alternate_translation, :deliver => :body)

      # assert delivery of the alternate translation for a delivered reply with an alternate translation
      # when the user's locale is different from the original delivered reply
      assert_deliver_alternate_translation(
        :delivered_reply_with_alternate_translation, :deliver => :alternate_translation, :locale => "en"
      )
    end
  end

  describe "#end_chat!" do
    it "should inform the user how to find a new friend" do
      method = :end_chat!
      args = [partner]
      interpolations = []

      assert_reply(method, :anonymous_chat_has_ended, :args => args, :interpolations => interpolations)
      args << {:skip_update_profile_instructions => true}
      assert_reply(method, :chat_has_ended, :args => args, :interpolations => interpolations)
    end
  end

  describe "#instructions_for_new_chat!" do
    it "should inform the user how to find a new friend" do
      assert_reply(:instructions_for_new_chat!, :chat_has_ended)
    end
  end

  describe "#logout!" do
    it "should confirm the user that they have been logged out and explain how to find a new friend" do
      assert_reply(:logout!, :anonymous_logged_out)
      assert_reply(:logout!, :logged_out_from_chat, :args => [partner], :interpolations => [partner.screen_id])
    end

    context "given an english user is only missing their sexual preference" do
      # special case

      let(:english_user_only_missing_sexual_preference) do
        build(:english_user_with_complete_profile, :looking_for => nil)
      end

      it "should tell them to text their preferred gender" do
        assert_reply(
          :logout!,
          :only_missing_sexual_preference_logged_out,
          :test_users => [english_user_only_missing_sexual_preference]
        )
      end
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

  describe "#explain_could_not_find_a_friend!" do
    it "should tell the user that their chat could not be started at this time" do
      assert_reply(:explain_could_not_find_a_friend!, :anonymous_could_not_find_a_friend)
    end
  end

  describe "#explain_friend_is_unavailable!" do
    it "should send a message from the friend saying that they're busy" do
      assert_reply(
        :explain_friend_is_unavailable!, :friend_unavailable,
        :args => [partner], :interpolations => [partner.screen_id]
      )
    end
  end

  describe "#forward_message" do
    it "should show the message in a chat context but not deliver the message" do
      assert_reply(
        :forward_message, :forward_message,
        :args => [partner, "#{partner.screen_id}: hi how r u doing"], :interpolations => [partner.screen_id, "hi how r u doing"],
        :deliver => false, :no_alternate_translation => true
      )
    end
  end

  describe "#forward_message!" do
    it "should deliver the forwarded message" do
      assert_reply(
        :forward_message!, :forward_message,
        :args => [partner, "#{partner.screen_id.downcase}  :  hi how r u doing"], :interpolations => [partner.screen_id, "hi how r u doing"],
        :no_alternate_translation => true
      )
    end
  end

  describe "#introduce!" do
    context "for the chat initiator" do
      it "should tell her that we have found a friend for her" do
        assert_reply(
          :introduce!, :anonymous_new_friend_found,
          :args => [partner, true], :interpolations => [partner.screen_id]
        )
      end
    end

    context "for the chat partner" do
      context "with no introduction" do
        it "should imitate the user by sending a fake greeting to the new chat partner" do
          assert_reply(
            :introduce!, :forward_message_approx,
            :args => [partner, false], :interpolations => [partner.screen_id],
            :no_alternate_translation => true, :approx => true
          )
        end
      end

      context "with an introduction" do
        it "should send the introduction to the new chat partner" do
          assert_reply(
            :introduce!, :forward_message,
            :args => [partner, false, "Hello Bobby"], :interpolations => [partner.screen_id, "Hello Bobby"],
            :no_alternate_translation => true
          )
        end
      end
    end
  end

  describe "#welcome!" do
    it "should welcome the user" do
      assert_reply(:welcome!, :welcome)
    end
  end
end
