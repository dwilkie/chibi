require 'rails_helper'

describe Chat do
  include_context "replies"
  include TranslationHelpers
  include MessagingHelpers
  include ActiveJobHelpers

  let(:user) { create(:user, :english) }
  let(:new_partner_for_user) { create(:user, :english) }
  let(:new_partner_for_friend) { create(:user) }
  let(:friend) { create(:user, :cambodian) }

  let(:chat) { create_chat }

  let(:new_chat) { create_chat(:build => true) }
  let(:active_chat) { create_chat(:active) }
  let(:unique_active_chat) { create(:chat, :active) }

  let(:active_chat_with_single_user) { create_chat(:initiator_active) }

  def create_chat(*traits)
    options = traits.extract_options!
    build = options.delete(:build)
    args = ([:chat] << [*traits]).flatten
    options = {:user => user, :friend => friend}.merge(options)
    build ? build(*args, options) : create(*args, options)
  end

  describe "factory" do
    it "should be valid" do
      expect(new_chat).to be_valid
    end
  end

  describe "validations" do
    subject { build(:chat) }
    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:friend) }
  end

  describe "#active?" do
    it "should only return true for chats which have active users" do
      expect(active_chat).to be_active
      active_chat.active_users.clear
      expect(active_chat).not_to be_active

      active_chat.active_users << user
      expect(active_chat).not_to be_active

      active_chat.active_users << friend
      expect(active_chat).to be_active
    end
  end

  describe "#activate!(options = {})" do
    let(:options) { {} }
    subject { build(:chat) }
    let(:initiator) { subject.user }
    let(:partner) { subject.friend }

    def setup_scenario
    end

    def make_assertions!
      expect(subject).to be_persisted
    end

    before do
      setup_scenario
      subject.activate!(options)
    end

    after do
      make_assertions!
    end

    context "by default" do
      it { is_expected.to be_active }
      it { expect(initiator).not_to be_searching_for_friend }
    end

    context "passing :activate_user => false" do
      let(:options) { { :activate_user => false } }
      it { is_expected.not_to be_active }
      it { expect(subject.active_users).to match_array([partner]) }
      it { expect(initiator).to be_searching_for_friend }
    end

    context "passing :notify => false" do
      let(:options) { { :notify => true } }
      it { expect(subject.replies).not_to be_empty }
    end

    context "passing :starter" do
      let(:starter) { create(:phone_call) }
      let(:options) { { :starter => starter } }

      it { expect(subject.starter).to eq(starter) }
    end

    context "given the initiator is already in another chat" do
      let(:current_active_chat) { create(:chat, :active, :user => initiator) }

      def setup_scenario
        expect(current_active_chat).to be_active
      end

      it { expect(current_active_chat).not_to be_active }
      it { expect(current_active_chat.reload.active_users).to match_array([current_active_chat.friend]) }
    end

    context "there's no friend for the chat" do
      subject { build(:chat, :friend => nil) }

      def make_assertions!
      end

      context "and a friend cannot be found" do
        it { is_expected.not_to be_persisted }
      end

      context "and a friend can be found" do
        def setup_scenario
          create(:user)
        end

        it { is_expected.to be_persisted }
      end
    end
  end

  describe "#reactivate!" do
    context "the chat is already active" do
      it "should not update the chat" do
        active_chat
        time_updated = active_chat.updated_at
        active_chat.reactivate!
        expect(active_chat.updated_at).to eq(time_updated)
        expect(active_chat).to be_active
      end
    end

    context "the chat is not active" do
      before do
        active_chat_with_single_user
        create(:chat, :active, :friend => friend)
      end

      it "should force reactivate the chat" do
        expect(active_chat_with_single_user).not_to be_active
        active_chat_with_single_user.reactivate!
        expect(active_chat_with_single_user).to be_active
      end

      context "and there are undelivered messages" do
        let(:reply) { create(:reply, :chat => active_chat_with_single_user) }

        it "should deliver the replies" do
          expect(reply).not_to be_delivered
          active_chat_with_single_user.reactivate!
          expect(reply.reload).to be_delivered
        end
      end
    end
  end

  describe "#deactivate!" do
    subject { create(:chat, :active) }
    let(:initiator) { subject.user }
    let(:partner) { subject.friend }

    let(:options) { {} }

    def setup_scenario
    end

    before do
      setup_scenario
      subject.deactivate!(options)
    end

    context "by default" do
      it { expect(subject.active_users).to be_empty }
    end

    context "if there are undelivered replies for a user in the chat" do
      let(:another_chat) { create(:chat, :user => initiator) }
      let(:reply) { create(:reply, :undelivered, :user => initiator, :chat => another_chat) }

      def setup_scenario
        reply
      end

      context "by default" do
        it { expect(another_chat.active_users).to match_array([initiator]) }
        it { expect(reply.reload).to be_delivered }

        context "user is in another chat" do
          let(:another_active_chat) { create(:chat, :active, :user => initiator) }

          def setup_scenario
            super
            another_active_chat
          end

          it { expect(another_chat.active_users).to be_empty }
          it { expect(reply.reload).not_to be_delivered }
        end
      end

      context "passing :reactivate_previous_chat => false" do
        let(:options) { {:reactivate_previous_chat => false} }

        it { expect(another_chat.active_users).to be_empty }
        it { expect(reply.reload).not_to be_delivered }
      end
    end

    context "passing :activate_new_chats => true" do
      let(:options) { {:activate_new_chats => true} }

      def setup_scenario
        create_list(:user, 10)
      end

      def assert_new_chats_activated!(*reference_users)
        reference_users.each do |reference_user|
          expect(reference_user).not_to be_currently_chatting
          expect(reference_user.chats.count).to be > 1
        end
      end

      it { assert_new_chats_activated!(initiator, partner) }
    end

    context "passing :for => #<User...>" do
      let(:options) { {:for => initiator} }

      it { expect(subject.active_users).to match_array([partner]) }

      context "the partner of the passed user is already in a new chat" do
        let(:partners_active_chat) { create(:chat, :active, :user => partner) }

        def setup_scenario
          partners_active_chat
          subject.reload
        end

        it { expect(partners_active_chat).to be_active }
        it { expect(subject.active_users).to be_empty }
      end
    end
  end

  describe "#reinvigorate!" do
    let(:chat) { create(:chat, :user => user) }

    def do_reinvigorate!
      chat.reinvigorate!
    end

    context "given there are undelivered replies for the participants in this chat" do
      let(:undelivered_replies) { create_list(:reply, 2, :user => user, :chat => chat) }

      before do
        undelivered_replies
      end

      context "and the participants are not currently chatting" do
        before do
          do_reinvigorate!
        end

        it "should deliver the replies to the participants and mark this as their active chat" do
          expect(chat.active_users).to eq([user]) # just make the chat active for the recipient of the reply
          undelivered_replies.each do |undelivered_reply|
            expect(undelivered_reply.reload).to be_delivered
          end
        end
      end

      context "and the participants are busy chatting with someone else" do
        before do
          create(:chat, :active, :user => user)
          do_reinvigorate!
        end

        it "should not delivery the replies or mark this as their active chat" do
          expect(chat.active_users).to be_empty
          undelivered_replies.each do |undelivered_reply|
            expect(undelivered_reply.reload).not_to be_delivered
          end
        end
      end
    end

    context "given there are no undelivered replies for the participants in this chat" do
      before do
        do_reinvigorate!
      end

      it "should not reinvigorate the chat" do
        expect(chat.active_users).to be_empty
      end
    end
  end

  describe "#forward_message" do
    let(:sender) { create(:user) }
    let(:recipient) { create(:user) }
    let(:message_body) { "hello" }
    let(:message) { create(:message, :body => message_body, :user => sender) }
    let(:reply) { subject.replies.last! }

    subject { create(:chat, :initiator_active, :user => sender, :friend => recipient) }

    def setup_scenario
    end

    def make_assertions!
      expect(subject.messages).to include(message)
      expect(reply.body).to include(message_body)
    end

    before do
      setup_scenario
      subject.forward_message(message)
    end

    after do
      make_assertions!
    end

    context "given the friend is available to chat" do
      it { is_expected.to be_active }

      def make_assertions!
        super
        expect(reply).to be_delivered
      end

      context "but the chat is one-sided" do
        def setup_scenario
          create(:user)
          create(:phone_call, :chat => subject, :user => sender)
          create(:message, :chat => subject, :user => sender)
        end

        it { subject.reload; is_expected.not_to be_active }
      end
    end

    context "given the recipient is unavailable to chat" do
      def setup_scenario
        create(:chat, :active, :user => recipient)
      end

      def make_assertions!
        super
        expect(reply).not_to be_delivered
      end

      it { is_expected.not_to be_active }

      context "it should try to find the sender some new friends" do
        let(:new_partner) { create(:user) }

        def setup_scenario
          super
          new_partner
        end

        it { expect(new_partner.reload.active_chat.user).to eq(sender) }
      end
    end
  end

  describe "#partner" do
    it "should return the partner of the given user" do
      expect(new_chat.partner(new_chat.user)).to eq(new_chat.friend)
      expect(new_chat.partner(new_chat.friend)).to eq(new_chat.user)
    end
  end

  describe "#initiator" do
    it "should be an alias for the attribute '#from'" do
      user = User.new

      subject.initiator = new_chat.user
      expect(subject.user).to eq(new_chat.user)

      user = User.new

      subject.user = user
      expect(subject.initiator).to eq(user)
    end
  end

  describe ".activate_multiple!(initiator, options = {})" do
    let(:options) { {} }
    let(:initiator) { create(:user) }
    let(:active_chat) { create(:chat, :active, :user => initiator) }
    let(:new_chats) { described_class.all - [active_chat] }

    before do
      setup_scenario
      described_class.activate_multiple!(initiator, options)
    end

    def setup_scenario
      active_chat
      create_list(:user, 10)
    end

    it { expect(initiator.reload).not_to be_currently_chatting }

    context "by default" do
      it "should create 5 new chats for the initiator" do
        expect(new_chats.count).to eq(5)

        new_chats.each do |chat|
          expect(chat.active_users).to match_array([chat.friend])
        end
      end
    end

    context "passing :notify => true" do
      let(:options) { { :notify => true } }

      it "should send notifications to the chat partners" do
        new_chats.each do |chat|
          expect(chat.replies).not_to be_empty
        end
      end
    end
  end

  it_should_behave_like "filtering with communicable resources" do
    let(:resources) { [chat, unique_active_chat] }
  end

  describe ".intended_for(message)" do
    let(:sender) { create(:user, :name => "bill") }
    let(:active_chat) { create(:chat, :active, :user => sender) }

    let(:bob) { create(:user, :name => "bob") }
    let(:dave) { create(:user, :name => "dave") }
    let(:chris) { create(:user, :name => "chris") }
    let(:fake_bill) { create(:user, :screen_name => "bill") }
    let(:real_bill) { create(:user, :name => "bill") }

    let(:chat_between_sender_and_bob) { create(:chat, :user => sender, :friend => bob) }
    let(:chat_between_sender_and_dave) { create(:chat, :initiator_active, :user => dave, :friend => sender) }
    let(:chat_between_sender_and_chris) { create(:chat, :user => sender, :friend => chris) }
    let(:chat_between_sender_and_fake_bill) { create(:chat, :user => sender, :friend => fake_bill) }
    let(:chat_between_sender_and_real_bill) { create(:chat, :user => sender, :friend => real_bill) }

    let(:reply_from_bob_to_sender) {
      create(:reply, :chat => chat_between_sender_and_bob, :user => sender, :body => "Bob: blah blah blah")
    }

    let(:reply_from_dave_to_sender) {
      create(:reply, :chat => chat_between_sender_and_dave, :user => sender, :body => "Dave: foo bar baz")
    }

    let(:reply_from_sender_to_chris) {
      create(:reply, :chat => chat_between_sender_and_chris, :user => chris, :body => "Bill: hello what's up?")
    }

    let(:reply_from_sender_to_fake_bill) {
      create(:reply, :chat => chat_between_sender_and_fake_bill, :user => sender, :body => "Bill: Hi bill i'm not really bill")
    }

    let(:reply_from_sender_to_real_bill) {
      create(:reply, :chat => chat_between_sender_and_fake_bill, :user => sender, :body => "Bill: Hi i'm really bill!")
    }

    let(:message) { create(:message, :user => sender) }

    let(:messages_from_sender_to_bob) { ["Hi bob! how are you today?", "Bob: How are you?"] }
    let(:messages_from_sender_to_dave) { ["How are you dave?", "Dave: Soksabai", "Chheng: Dave: suosdey nhom chheng nov kean sviy nhom jong ban lek nak"] }
    let(:messages_from_sender_to_current_partner) { ["Hi! Welcome!", "Can I have your number?", "How are u", "im davey crocket", "i have a bobcat", "Hi Chris how are you?"] }
    let(:messages_from_sender) { ["Hi! I'm Bill!", "Bill: that's me"] }

    before do
      reply_from_bob_to_sender
      active_chat
      reply_from_dave_to_sender
      reply_from_sender_to_chris
      reply_from_sender_to_fake_bill
      reply_from_sender_to_real_bill
    end

    it "should try to determine the chat in which the message is intended for" do

      messages_from_sender_to_bob.each do |bob_message|
        message.body = bob_message
        expect(described_class.intended_for(message)).to eq(chat_between_sender_and_bob)
      end

      messages_from_sender_to_dave.each do |dave_message|
        message.body = dave_message
        expect(described_class.intended_for(message)).to eq(chat_between_sender_and_dave)
      end

      messages_from_sender.each do |bill_message|
        message.body = bill_message
        expect(described_class.intended_for(message)).to be_nil
      end

      # Note:
      # Messages to Chris are ignored because our user has never received
      # a message from Chris even though he has previously been in a chat with him
      # e.g. if a chat was originated from Dave to Chris but Chris never replied
      messages_from_sender_to_current_partner.each do |current_partner_message|
        message.body = current_partner_message
        expect(described_class.intended_for(message)).to be_nil
      end
    end
  end

  describe ".filter_by" do
    it "should include users, friends & active users to avoid loading them for each user" do
      expect(subject.class.filter_by.includes_values).to include(:user, :friend, :active_users)
    end

    context ":user_id => 2" do
      before do
        chat
        unique_active_chat
      end

      it "should return all chats with the given user id" do
        expect(subject.class.filter_by(:user_id => chat.user_id)).to eq([chat])
      end
    end
  end

  describe ".filter_by_count" do
    context ":user_id => 2" do
      before do
        chat
        unique_active_chat
      end

      it "should return the count of the chats with the given user id" do
        expect(subject.class.filter_by_count(:user_id => chat.user_id)).to eq(1)
      end
    end
  end

  describe ".reinvigorate!" do
    context "with pending replies" do
      let(:pending_reply) { create(:reply, :user => user, :chat => chat) }
      let(:job) { enqueued_jobs.first }

      before do
        pending_reply
        trigger_job(:queue_only => true) { described_class.reinvigorate! }
      end

      context "even if the reply recipient is currently chatting" do
        let(:chat) { create(:chat, :active, :user => user) }

        it "should still queue a job to try and reinvigorate the chat" do
          expect(job[:args].first).to eq(chat.id)
        end
      end

      context "the reply recipient is offline" do
        let(:user) { create(:user, :offline) }

        it "should not queue a job to reinvigorate the chat" do
          expect(job).to eq(nil)
        end
      end
    end
  end

  describe ".cleanup!" do
    let(:time_considered_old) { 30.days.ago }

    def create_old_chat(*args)
      options = args.extract_options!
      interaction = options.delete(:interaction)
      user = options.delete(:user)
      factory_options = {:created_at => time_considered_old, :updated_at => time_considered_old}.merge(options)
      chat = create(:chat, *args, factory_options)
      create(interaction, :chat => chat) if interaction
      chat.update_attribute(:updated_at, time_considered_old)
      chat
    end

    let(:old_active_chat) { create_old_chat(:active) }
    let(:old_chat_with_initiator_active) { create_old_chat(:initiator_active) }
    let(:old_chat_with_friend_active) { create_old_chat(:friend_active) }
    let(:old_chat_with_message) { create_old_chat(:interaction => :message) }
    let(:old_chat_with_phone_call) { create_old_chat(:interaction => :phone_call) }

    before do
      chat
      unique_active_chat
      old_active_chat
      old_chat_with_message
      old_chat_with_phone_call
      old_chat_with_initiator_active
      old_chat_with_friend_active
      old_chat_with_friend_active.active_users
      create_old_chat(:interaction => :reply)
      described_class.cleanup!
    end

    it "should cleanup any chats without interaction that are older than 30 days" do
      expect(Chat.all).to match_array([
        chat, unique_active_chat, old_active_chat, old_chat_with_initiator_active,
        old_chat_with_friend_active, old_chat_with_message, old_chat_with_phone_call
      ])
    end
  end

  describe "chat expiry" do
    def create_chat(*args)
      options = args.extract_options!
      create(:chat, :active, *args, options)
    end

    let(:chat_will_permanently_timeout) { create_chat(:will_permanently_timeout) }
    let(:chat_will_provisionally_timeout) { create_chat(:will_provisionally_timeout) }
    let(:active_chat) { create_chat }

    def setup_scenario
    end

    describe "#expire!(mode)" do
      before do
        setup_scenario
        subject.expire!(mode)
      end

      context "'permanent' mode" do
        let(:mode) { "permanent" }

        context "for a chat which has inactivity" do
          subject { chat_will_permanently_timeout }

          it "should permanently timeout the chat" do
            is_expected.not_to be_active
            expect(subject.active_users).to be_empty
          end
        end

        context "for a chat which has activity" do
          subject { active_chat }
          it { is_expected.to be_active }
        end
      end

      context "'provisional' mode'" do
        let(:mode) { "provisional" }

        context "for a chat which has inactivity" do
          subject { chat_will_provisionally_timeout }

          let(:form_of_activity) { :message }

          def setup_scenario
            updated_at = subject.updated_at
            create(form_of_activity, :user => user_with_activity, :chat => subject) if user_with_activity
            subject.update_column(:updated_at, updated_at)
          end

          after do
            is_expected.not_to be_active
          end

          context "with no chat activity" do
            let(:user_with_activity) { nil }
            it { expect(subject.active_users).to match_array([subject.friend]) }
          end

          context "with activity from the initiator" do
            let(:user_with_activity) { subject.user }
            it { expect(subject.active_users).to match_array([subject.friend]) }
          end

          context "with activity from the partner" do
            let(:form_of_activity) { :phone_call }
            let(:user_with_activity) { subject.friend }
            it { expect(subject.active_users).to match_array([subject.user]) }
          end
        end

        context "for a chat which has activity" do
          subject { active_chat }
          it { is_expected.to be_active }
        end

        context "for a chat which is not active" do
          subject { create(:chat, :friend_active) }
          it { expect(subject.active_users).to match_array([subject.friend]) }
        end
      end
    end

    describe ".expire(mode)" do
      def do_expire!
        trigger_job(:only => [ChatExpirerJob]) { described_class.expire!(mode) }
      end

      before do
        expect(active_chat).to be_active
        expect(chat_will_permanently_timeout).to be_active
        expect(chat_will_provisionally_timeout).to be_active
        do_expire!
      end

      after do
        expect(active_chat).to be_active
      end

      context "'permanent' mode" do
        let(:mode) { "permanent" }

        it "should permanently expire all timed out chats past the expiry period" do
          chat_will_permanently_timeout.reload
          expect(chat_will_permanently_timeout).not_to be_active
          expect(chat_will_permanently_timeout.active_users).to be_empty
          expect(chat_will_provisionally_timeout).to be_active
        end
      end

      context "'provisional' mode" do
        let(:mode) { "provisional" }

        it "should provisonally expire all timed out chats past the expiry period" do
          chat_will_permanently_timeout.reload
          expect(chat_will_permanently_timeout).not_to be_active
          expect(chat_will_permanently_timeout.active_users).not_to be_empty
          expect(chat_will_provisionally_timeout).not_to be_active
          expect(chat_will_provisionally_timeout.active_users).not_to be_empty
        end
      end
    end

    describe ".will_timeout(mode)" do
      let(:results) { described_class.will_timeout(mode) }
      let(:active_chat) { create(:chat, :active, :will_permanently_timeout) }
      let(:partially_active_chat) { create(:chat, :initiator_active, :will_permanently_timeout) }

      before do
        active_chat
        partially_active_chat
      end

      context "'provisional_mode'" do
        let(:mode) { "provisional" }

        it { expect(results.joins_values.uniq).to match_array([:active_users, :user, :friend]) }
        it { expect(results).to match_array([active_chat]) }
      end

      context "'permanent_mode'" do
        let(:mode) { "permanent" }

        it { expect(results).to match_array([active_chat, partially_active_chat]) }
      end
    end
  end
end
