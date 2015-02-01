require 'spec_helper'

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

  let(:active_chat_with_inactivity) { create(:chat, :active, :with_inactivity, :user => user) }
  let(:active_chat_with_single_user_with_inactivity) { create(:chat, :initiator_active, :with_inactivity) }
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
      new_chat.should be_valid
    end
  end

  describe "validations" do
    it "should not be valid without a user" do
      new_chat.user = nil
      new_chat.should_not be_valid
    end

    it "should not be valid without a friend" do
      new_chat.friend = nil
      new_chat.should_not be_valid
    end

    it "should not be valid with a duplicate user and friend" do
      chat
      new_chat.user = chat.user
      new_chat.friend = chat.friend
      new_chat.should_not be_valid
    end
  end

  describe "#active?" do
    it "should only return true for chats which have active users" do
      active_chat.should be_active
      active_chat.active_users.clear
      active_chat.should_not be_active

      active_chat.active_users << user
      active_chat.should_not be_active

      active_chat.active_users << friend
      active_chat.should be_active
    end
  end

  describe "#activate" do
    before do
      subject.stub(:activate!)
    end

    it "should pass the options to #activate!" do
      subject.should_receive(:activate!).with({:some_option => "some option"})
      subject.activate({:some_option => "some option"})
    end

    it "should return whether on not the chat is active" do
      subject.stub(:active?).and_return(true)
      subject.activate.should == true

      subject.stub(:active?).and_return(false)
      subject.activate.should == false
    end
  end

  describe "#activate!(options = {})" do
    shared_examples_for "activating a chat" do
      it "should set the active users and save the chat" do
        reference_chat.activate!
        reference_chat.should be_active
        reference_chat.should be_persisted
        user.active_chat.should == reference_chat
        friend.active_chat.should == reference_chat
      end

      context "passing :activate_user => false" do
        before do
          reference_chat.activate!(:activate_user => false)
        end

        it "should only activate the chat for the friend" do
          reference_chat.should_not be_active
          reference_chat.should be_persisted
          user.active_chat.should be_nil
          friend.active_chat.should == reference_chat
        end

        context "the initiator" do
          it "should be searching for friend" do
            user.reload.should be_searching_for_friend
            friend.reload.should_not be_searching_for_friend
          end
        end
      end

      context "passing :notify => true" do
        it "should introduce only the chat partner" do
          expect_message { reference_chat.activate!(:notify => true) }

          reply_to(user, reference_chat).should be_nil
          reply_to(friend, reference_chat).body.should =~ /#{spec_translate(:forward_message_approx, friend.locale, user.screen_id)}/
        end
      end

      context "passing no options" do
        before do
          reference_chat.activate!
        end

        context "the initiator" do
          it "should not be searching for a friend" do
            reference_chat.user.reload.should_not be_searching_for_friend
            reference_chat.friend.reload.should_not be_searching_for_friend
          end
        end

        it "should not introduce the new chat participants" do
          reply_to(user, reference_chat).should be_nil
          reply_to(friend, reference_chat).should be_nil
        end
      end
    end

    context "passing :starter" do
      [:message, :phone_call].each do |starter|
        context "=> #<#{starter.to_s.classify}...>" do
          it "should set the starter as the #{starter}" do
            chat_starter = create(starter)
            chat.activate!(:starter => chat_starter)
            chat.starter.should == chat_starter
          end
        end
      end
    end

    context "given the user is currently in another chat" do
      let(:current_chat_partner) { create(:user) }
      let(:current_active_chat) { create(:chat, :active, :user => user, :friend => current_chat_partner) }

      before do
        current_active_chat
      end

      it "should deactivate the other chat for the new user but leave the partner active" do
        new_chat.activate!
        current_active_chat.should_not be_active
        current_active_chat.reload.active_users.should == [current_chat_partner]
      end

      context "passing :notify => true" do
        it "should not inform the previous chat partner how to find a new friend" do
          expect_message { new_chat.activate!(:notify => true) }
          reply_to(current_chat_partner, current_active_chat).should be_nil
          reply_to(user, current_active_chat).should be_nil
        end
      end
    end

    context "given the chat already has a friend" do
      it_should_behave_like "activating a chat" do
        let(:reference_chat) { new_chat }
      end
    end

    context "given the chat is missing a friend" do
      before do
        subject.user = user
      end

      it "should try to find a friend for the user" do
        user.should_receive(:match)
        subject.activate!
      end

      context "and a friend is found for this user" do
        before do
          user.stub(:match).and_return(friend)
        end

        it_should_behave_like "activating a chat" do
          let(:reference_chat) { subject }
        end
      end

      context "and a friend could not be found for this user" do

        shared_examples_for "not notifying the user of no match" do
          it "should not notify the user that there are no matches at this time" do
            subject.activate!
            reply_to(user).should be_nil
          end
        end

        before do
          user.stub(:match).and_return(nil)
        end

        context "passing :notify => true" do
          it_should_behave_like "not notifying the user of no match"
        end

        context "passing no options" do
          before do
            subject.activate!
          end

          it_should_behave_like "not notifying the user of no match"
        end
      end
    end
  end

  describe "#reactivate!" do
    context "the chat is already active" do
      it "should not update the chat" do
        active_chat
        time_updated = active_chat.updated_at
        active_chat.reactivate!
        active_chat.updated_at.should == time_updated
        active_chat.should be_active
      end
    end

    context "the chat is not active" do
      before do
        active_chat_with_single_user
        create(:chat, :active, :friend => friend)
      end

      it "should force reactivate the chat" do
        active_chat_with_single_user.should_not be_active
        active_chat_with_single_user.reactivate!
        active_chat_with_single_user.should be_active
      end

      context "and there are undelivered messages" do
        let(:reply) { create(:reply, :chat => active_chat_with_single_user) }

        it "should deliver the replies" do
          reply.should_not be_delivered
          expect_message { active_chat_with_single_user.reactivate! }
          reply.reload.should be_delivered
        end
      end
    end
  end

  describe "#deactivate!" do
    def assert_active_users_cleared
      active_chat.active_users.should be_empty
      active_chat.should_not be_active
    end

    context "passing 'inactivity_cutoff'" do
      context "for a chat with inactivity" do
        it "should deactivate the chat" do
          active_chat_with_inactivity.deactivate!("inactivity_cutoff" => 9.minutes.ago.to_s)
          active_chat_with_inactivity.should_not be_active
        end
      end

      context "passing 'inactivity_cutoff' => 11.minutes.ago.to_s" do
        it "should not deactivate the chat" do
          active_chat_with_inactivity.deactivate!("inactivity_cutoff" => 11.minutes.ago.to_s)
          active_chat_with_inactivity.should be_active
        end
      end

      context "for a chat that has activity" do
        it "should not deactivate the chat" do
          active_chat.deactivate!("inactivity_cutoff" => 10.minutes.ago.to_s)
          active_chat.should be_active
        end
      end
    end

    context "passing 'activate_new_chats' => true" do
      def assert_new_chat_created(reference_user, new_friend)
        reference_user.reload

        new_chat = subject.class.where(:friend_id => new_friend).first
        new_chat.user.should == reference_user
        new_chat.friend.should == new_friend
        new_chat.active_users.should == [new_friend]

        reference_user.should_not be_currently_chatting
      end

      before do
        new_partner_for_user
        new_partner_for_friend
      end

      it "should create new chats for the old users of this chat" do
        expect_message { active_chat.deactivate!("activate_new_chats" => true) }
        assert_active_users_cleared

        assert_new_chat_created(user, new_partner_for_user)
        assert_new_chat_created(friend, new_partner_for_friend)
      end
    end

    context "passing 'active_user' => #<User...A>" do
      context "and #<User...B> is not currently chatting with #<User...C>" do
        it "should only deactivate the chat for #<User...A> and leave #<User...B> active" do
          # so that they are available to chat with someone else
          active_chat.deactivate!("active_user" => user)
          active_chat.active_users.should == [friend]
        end
      end

      context "but #<User...B> is now currently chatting with #<User...C>" do
        before do
          active_chat_with_single_user
          create(:chat, :active, :user => friend)
        end

        it "should deactivate the chat for both #<User...A> and #<User...B>" do
          # so that they are available to chat with someone else
          active_chat_with_single_user.deactivate!("active_user" => user)
          active_chat_with_single_user.active_users.should == []
        end
      end
    end

    context "passing 'active_user' => true" do
      context "given there are no replies for this chat" do
        context "and no inactive user" do
          before do
            active_chat.deactivate!("active_user" => true)
          end

          it "should deactivate the chat for both users" do
            active_chat.active_users.should be_empty
            active_chat.should_not be_active
          end
        end

        context "but there is an inactive user" do
          before do
            active_chat_with_single_user.deactivate!("active_user" => true)
          end

          it "should only deactivate the chat for the active user" do
            active_chat_with_single_user.active_users.should == [user]
            active_chat_with_single_user.should_not be_active
          end

        end
      end

      context "given there are replies for this chat" do
        before do
          create(:reply, :delivered, :chat => active_chat, :user => user)
        end

        context "and the last reply was to the user" do
          before do
            active_chat.deactivate!("active_user" => true)
          end

          it "should deactivate the chat for the friend" do
            active_chat.active_users.should == [user]
          end
        end

        context "and the last reply was to the friend" do
          before do
            rep = create(:reply, :delivered, :chat => active_chat, :user => friend)
            active_chat.deactivate!("active_user" => true)
          end

          it "should deactivate the chat for the user" do
            active_chat.active_users.should == [friend]
          end
        end
      end

      context "given there are undelivered replies for the deactivated users" do
        let(:expired_chats) { create_list(:chat, 2, :user => user) }

        let(:pending_replies) do
          [create(:reply, :user => user, :chat => expired_chats[0]), create(:reply, :user => user, :chat => expired_chats[1])]
        end

        let(:chat_to_deactivate) { create(:chat, :user => user) }

        def do_deactivate!(options = {})
          chat_to_deactivate.deactivate!(options)
        end

        def assert_chat_reactivated
          user.reload.active_chat.should == expired_chats[0]
          pending_replies[0].reload.should be_delivered
          pending_replies[1].reload.should_not be_delivered
        end

        def assert_chat_not_reactivated
          user.reload
          expired_chats.each do |expired_chat|
            user.active_chat.should_not == expired_chat
          end

          pending_replies.each do |pending_reply|
            pending_reply.reload.should_not be_delivered
          end
        end

        before do
          chat_to_deactivate
          pending_replies
        end

        it "should deliver undelivered replies by default" do
          do_deactivate!
          assert_chat_reactivated
        end

        context "passing :reactivate_previous_chat => false" do
          it "should not deliver any replies" do
            do_deactivate!(:reactivate_previous_chat => false)
            assert_chat_not_reactivated
          end
        end

        it "should not deliver replies to a logged out user" do
          user.logout!
          do_deactivate!
          assert_chat_not_reactivated
        end

        it "should not deliver replies a user who is in a chat" do
          create(:chat, :active, :user => user)
          do_deactivate!
          assert_chat_not_reactivated
        end
      end
    end

    context "passing no options" do
      it "should clear the active users" do
        active_chat.deactivate!
        assert_active_users_cleared
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
          chat.active_users.should == [user] # just make the chat active for the recipient of the reply
          undelivered_replies.each do |undelivered_reply|
            undelivered_reply.reload.should be_delivered
          end
        end
      end

      context "and the participants are busy chatting with someone else" do
        before do
          create(:chat, :active, :user => user)
          do_reinvigorate!
        end

        it "should not delivery the replies or mark this as their active chat" do
          chat.active_users.should be_empty
          undelivered_replies.each do |undelivered_reply|
            undelivered_reply.reload.should_not be_delivered
          end
        end
      end
    end

    context "given there are no undelivered replies for the participants in this chat" do
      before do
        do_reinvigorate!
      end

      it "should not reinvigorate the chat" do
        chat.active_users.should be_empty
      end
    end
  end

  describe "#inactive_user" do
    it "should return the active user if he is the only active user in the chat" do
      create(:chat, :initiator_active, :user => user).inactive_user.should == user
      create(:chat, :friend_active, :friend => friend).inactive_user.should == friend
      create(:chat, :active).inactive_user.should be_nil
      create(:chat).inactive_user.should be_nil # expired
    end
  end

  describe "#forward_message" do
    def create_message(user, chat = nil)
      create(:message, :user => user, :body => "#{user.screen_id}: #{message_body}", :chat => chat)
    end

    let(:message_body) { "hello" }
    let(:message) { create_message(user) }

    def assert_forward_message_to(recipient, originator, chat_session, message, options = {})
      chat_session.reload.messages.should include(message)
      reply = reply_to(recipient, chat_session)
      reply.body.should == spec_translate(
        :forward_message, recipient.locale, originator.screen_id, message_body
      )

      options[:delivered] = true unless options[:delivered] == false

      if options[:delivered]
        recipient.active_chat.should == chat_session
        originator.active_chat.should == chat_session
        reply.should be_delivered
      else
        reply.should_not be_delivered
      end
    end

    context "given the friend is available to chat" do
      it "should forward the message to the friend and put the friend in the active chat" do
        time_updated = active_chat_with_single_user.updated_at
        expect_message { active_chat_with_single_user.forward_message(message) }
        assert_forward_message_to(friend, user, active_chat_with_single_user, message)
        active_chat_with_single_user.updated_at.should > time_updated
      end

      context "and the originator has already sent one message" do
        before do
          create_message(user, active_chat_with_single_user)
          new_partner_for_user
        end

        it "should just forward the message" do
          expect_message { active_chat_with_single_user.forward_message(message) }
          assert_forward_message_to(friend, user, active_chat_with_single_user, message)
          user.reload.should be_currently_chatting
          new_partner_for_user.reload.should_not be_currently_chatting
        end

        context "and the originator has already sent another message" do
          before do
            create_message(user, active_chat_with_single_user)
          end

          it "should forward the message and start a new chat for the originator" do
            expect_message do
              active_chat_with_single_user.forward_message(message)
            end

            user.reload.should_not be_currently_chatting
            new_partner_for_user.reload.should be_currently_chatting
            new_partner_for_user.active_chat.starter.should == message

            reply_to(new_partner_for_user).body.should =~ /#{spec_translate(:forward_message_approx, new_partner_for_user.locale, user.screen_id)}/
          end
        end
      end
    end

    context "given the friend is unavailable to chat" do
      let(:sender) { user }
      let(:unavailable_user) { friend }
      let(:current_chat_session) { create(:chat, :initiator_active, :user => sender, :friend => unavailable_user) }
      let(:message_to_be_forwarded) { create(:message, :user => sender, :body => message_body) }

      def do_forward_message
        expect_message { current_chat_session.forward_message(message) }
      end

      def assert_forward_message_to
        super(unavailable_user, sender, current_chat_session, message, :delivered => false)
      end

      before do
        # create a new active chat for the unavailable user so they're unavailable
        create(:chat, :active, :user => unavailable_user)
      end

      context "and there are no pending replies for the sender" do
        let(:new_partner_for_sender) { new_partner_for_user }

        before do
          new_partner_for_sender
          do_forward_message
        end

        it "should save the message for sending later and find new friends for the sender" do
          # assert that the sender is now not in the chat session
          sender.active_chat.should be_nil

          new_chat_session = message.triggered_chats.first

          # assert that the sender's message triggered another chat
          new_chat_session.should be_present

          # assert that the new chat session is not the current chat session
          new_chat_session.should_not == current_chat_session

          # assert that an introduction was sent to the new friend
          reply_to(new_partner_for_sender).body.should =~ /#{spec_translate(:forward_message_approx, new_partner_for_sender.locale, sender.screen_id)}/

          # assert that the original message was queued for forwarding to the
          # unavailable user
          assert_forward_message_to
        end
      end

      context "and there are pending replies for the sender" do
        let(:expired_chat_with_sender) { create(:chat, :friend => sender) }

        let(:pending_reply_from_expired_chat) do
          create(:reply, :user => sender, :chat => expired_chat_with_sender)
        end

        before do
          pending_reply_from_expired_chat
          do_forward_message
        end

        it "should reinvigorate the chat with pending replies" do
          sender.active_chat.should == expired_chat_with_sender
          reply = reply_to(sender)
          reply.should == pending_reply_from_expired_chat
          reply.should be_delivered
          assert_forward_message_to
        end
      end
    end
  end

  describe "#partner" do
    it "should return the partner of the given user" do
      new_chat.partner(new_chat.user).should == new_chat.friend
      new_chat.partner(new_chat.friend).should == new_chat.user
    end
  end

  describe "#initiator" do
    it "should be an alias for the attribute '#from'" do
      user = User.new

      subject.initiator = new_chat.user
      subject.user.should == new_chat.user

      user = User.new

      subject.user = user
      subject.initiator.should == user
    end
  end

  describe ".activate_multiple" do
    before do
      create_list(:user, 10)
    end

    def with_new_chats(&block)
      subject.class.all.each do |chat|
        yield chat
      end
    end

    context "passing no options" do
      it "should create 5 new chats for the user" do
        subject.class.activate_multiple!(friend)
        subject.class.count.should == 5
        friend.reload.active_chat.should be_nil

        with_new_chats do |chat|
          chat.user.should == friend
          chat.active_users.should == [chat.friend]
        end
      end
    end

    context "passing :count => 7" do
      it "should create 7 new chats for the user" do
        subject.class.activate_multiple!(friend, :count => 7)
        subject.class.count.should == 7
      end
    end

    context "passing :notify => true" do
      it "should notify the all the new friends" do
        expect_message { subject.class.activate_multiple!(friend, :notify => true) }
        reply_to(friend).should be_nil

        with_new_chats do |chat|
          new_friend = chat.friend
          reply_to(new_friend).body.should =~ /#{spec_translate(:forward_message_approx, new_friend.locale, friend.screen_id)}/
        end
      end
    end
  end

  it_should_behave_like "filtering with communicable resources" do
    let(:resources) { [chat, unique_active_chat] }
  end

  describe ".intended_for" do
    let(:bob) { create(:user, :name => "bob") }
    let(:dave) { create(:user, :name => "dave") }
    let(:chris) { create(:user, :name => "chris") }

    let(:chat_with_bob) { create(:chat, :user => user, :friend => bob) }
    let(:chat_with_dave) { create(:chat, :initiator_active, :user => dave, :friend => user) }
    let(:chat_with_chris) { create(:chat, :user => user, :friend => chris) }

    let(:reply_from_bob) { create(:reply, :chat => chat_with_bob, :user => user) }
    let(:reply_from_dave) { create(:reply, :chat => chat_with_dave, :user => user) }
    let(:reply_to_chris) { create(:reply, :chat => chat_with_chris, :user => chris) }

    let(:message) { create(:message, :user => user) }

    let(:messages_to_bob) { ["Hi bob! how are you today?", "Bob: How are you?"] }
    let(:messages_to_dave) { ["How are you dave?", "Dave: Soksabai", "Chheng: Dave: suosdey nhom chheng nov kean sviy nhom jong ban lek nak"] }
    let(:messages_to_current_partner) { ["Hi! Welcome!", "Can I have your number?", "How are u", "im davey crocket", "i have a bobcat", "Hi Chris how are you?"] }

    before do
      reply_from_bob
      active_chat
      reply_from_dave
      reply_to_chris
    end

    it "should try to determine the chat in which the message is intended for" do
      messages_to_bob.each do |bob_message|
        message.body = bob_message
        subject.class.intended_for(message).should == chat_with_bob
      end

      messages_to_dave.each do |dave_message|
        message.body = dave_message
        subject.class.intended_for(message).should == chat_with_dave
      end

      # Note:
      # Messages to Chris are ignored because our user has never received
      # a message from Chris even though he has previously been in a chat with him
      # e.g. if a chat was originated from Dave to Chris but Chris never replied
      messages_to_current_partner.each do |current_partner_message|
        message.body = current_partner_message
        subject.class.intended_for(message).should be_nil
      end
    end

    context "passing :num_recent_chats => 3" do
      it "should only look at the previous 3 chats for intended recipients" do
        messages_to_bob.each do |bob|
          subject.class.intended_for(message, :num_recent_chats => 3).should be_nil
        end

        messages_to_dave.each do |dave_message|
          message.body = dave_message
          subject.class.intended_for(message, :num_recent_chats => 3).should == chat_with_dave
        end
      end
    end
  end

  describe ".filter_by" do
    it "should include users, friends & active users to avoid loading them for each user" do
      subject.class.filter_by.includes_values.should include(:user, :friend, :active_users)
    end

    context ":user_id => 2" do
      before do
        chat
        unique_active_chat
      end

      it "should return all chats with the given user id" do
        subject.class.filter_by(:user_id => chat.user_id).should == [chat]
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
        subject.class.filter_by_count(:user_id => chat.user_id).should == 1
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
      create_old_chat(:interaction => :reply)
      create_old_chat
    end

    it "should cleanup any chats without interaction that are older than 30 days" do
      subject.class.cleanup!
      Chat.all.should =~ [
        chat, unique_active_chat, old_active_chat, old_chat_with_initiator_active,
        old_chat_with_friend_active, old_chat_with_message, old_chat_with_phone_call
      ]
    end
  end

  describe ".end_inactive" do
    before do
      chat.should_not be_active
      unique_active_chat.should be_active

      active_chat_with_inactivity.should be_active
      active_chat_with_single_user_with_inactivity.active_users.count.should == 1
    end

    after do
      chat.should_not be_active
      unique_active_chat.should be_active
    end

    def do_end_inactive(options = {})
      described_class.end_inactive({"inactivity_cutoff" => 9.minutes.ago.to_s}.merge(options))
    end

    context "for chats with inactivity in the last 10 minutes" do
      before do
        trigger_job { do_end_inactive }
      end

      it "should deactivate chats with more than 10 minutes of inactivity" do
        active_chat_with_inactivity.should_not be_active
        active_chat_with_single_user_with_inactivity.active_users.count.should == 1
      end
    end

    context "passing 'inactivity_cutoff' => 11.minutes.ago" do
      before do
        trigger_job { do_end_inactive("inactivity_cutoff" => 11.minutes.ago.to_s) }
      end

      it "should deactivate chats with more than 11 minutes of inactivity" do
        active_chat_with_inactivity.should be_active
      end
    end

    context "passing :all => true" do
      before do
        trigger_job { do_end_inactive(:all => true) }
      end

      it "should deactivate all chats with inactivity" do
        active_chat_with_inactivity.should_not be_active
        active_chat_with_single_user_with_inactivity.active_users.count.should be_zero
      end
    end
  end
end
