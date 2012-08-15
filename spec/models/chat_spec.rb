require 'spec_helper'

describe Chat do
  include_context "replies"
  include TranslationHelpers
  include MessagingHelpers

  let(:user) do
    create(:english)
  end

  let(:friend) do
    create(:cambodian)
  end

  let(:chat) do
    create(:chat, :user => user, :friend => friend)
  end

  let(:new_chat) do
    build(:chat, :user => user, :friend => friend)
  end

  let(:active_chat) do
    create(:active_chat, :user => user, :friend => friend)
  end

  let(:unique_active_chat) do
    create(:active_chat)
  end

  let(:active_chat_with_inactivity) do
    create(:active_chat_with_inactivity, :user => user, :friend => friend)
  end

  let(:active_chat_with_single_user) do
    create(:active_chat_with_single_user, :user => user, :friend => friend)
  end

  let(:active_chat_with_single_friend) do
    create(:active_chat_with_single_friend, :user => user, :friend => friend)
  end

  let(:active_chat_with_single_user_with_inactivity) do
    create(:active_chat_with_single_user_with_inactivity)
  end

  let(:reply_to_user) do
    reply_to(user, active_chat)
  end

  let(:reply_to_friend) do
    reply_to(friend, active_chat)
  end

  describe "factory" do
    it "should be valid" do
      new_chat.should be_valid
    end
  end

  it "should not be valid without a user" do
    new_chat.user = nil
    new_chat.should_not be_valid
  end

  it "should not be valid without a friend" do
    new_chat.friend = nil
    new_chat.should_not be_valid
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
      subject.activate.should be_true

      subject.stub(:active?).and_return(false)
      subject.activate.should be_false
    end
  end

  describe "#activate!" do
    shared_examples_for "activating a chat" do
      it "should set the active users and save the chat" do
        reference_chat.activate!
        reference_chat.should be_active
        reference_chat.should be_persisted
        user.active_chat.should == reference_chat
        friend.active_chat.should == reference_chat
      end

      context "passing :activate_user => false" do
        it "should only activate the chat for the friend" do
          reference_chat.activate!(:activate_user => false)
          reference_chat.should_not be_active
          reference_chat.should be_persisted
          user.active_chat.should be_nil
          friend.active_chat.should == reference_chat
        end
      end

      context "passing :notify => true" do
        it "should introduce only the chat partner" do
          expect_message { reference_chat.activate!(:notify => true) }

          reply_to(user, reference_chat).should be_nil
          reply_to(friend, reference_chat).body.should == spec_translate(:greeting_from_unknown_gender, friend.locale, user.screen_id)
        end

        context "and :notify_initator => true" do
          it "should introduce the initiator as well" do
            expect_message { reference_chat.activate!(:notify => true, :notify_initiator => true) }

            reply_to(friend, reference_chat).body.should == spec_translate(:greeting_from_unknown_gender, friend.locale, user.screen_id)

            reply_to(user, reference_chat).body.should == spec_translate(
              :anonymous_new_friend_found, user.locale, friend.screen_id
            )
          end
        end
      end

      context "passing no options" do
        it "should not introduce the new chat participants" do
          expect_message { reference_chat.activate! }
          reply_to(user, reference_chat).should be_nil
          reply_to(friend, reference_chat).should be_nil
        end
      end
    end

    context "given the user is currently in another chat" do
      let(:current_chat_partner) { create(:user) }
      let(:current_active_chat) { create(:active_chat, :user => user, :friend => current_chat_partner) }

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

        context "and :notify_previous_partner => true" do
          it "should inform the previous chat partner how to find a new friend" do
            expect_message { new_chat.activate!(:notify => true, :notify_previous_partner => true) }
            reply_to(current_chat_partner, current_active_chat).body.should == spec_translate(
              :chat_has_ended, current_chat_partner.locale
            )
          end
        end
      end

      context "passing no options" do
        it "should not inform the current chat partner how to find a new friend" do
          new_chat.activate!
          reply_to(current_chat_partner, current_active_chat).should be_nil
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
          it "should notify the user that there are no matches at this time" do
            expect_message { subject.activate!(:notify => true) }
            reply_to(user).body.should == spec_translate(:anonymous_could_not_find_a_friend, user.locale)
          end

          context "with :notify_no_match => false" do
            before do
              subject.activate!(:notify => true, :notify_no_match => false)
            end

            it_should_behave_like "not notifying the user of no match"
          end
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
      it "should reactivate the chat" do
        new_chat.should_not be_active
        new_chat.reactivate!
        new_chat.should be_active
        new_chat.should be_persisted
      end

      context "and there are undelivered messages" do
        let(:reply) { create(:reply, :chat => chat) }

        it "should deliver the replies" do
          reply.should_not be_delivered
          expect_message { chat.reactivate! }
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

    it "should create new chats for the old users of this chat" do
      new_partner_for_user = create(:english)
      new_partner_for_friend = create(:user)

      expect_message { active_chat.deactivate! }
      assert_active_users_cleared

      user.reload
      friend.reload

      new_users_chat = subject.class.where(:friend_id => new_partner_for_user).first
      new_users_chat.user.should == user
      new_users_chat.friend.should == new_partner_for_user
      new_users_chat.active_users.should == [new_partner_for_user]

      new_partners_chat = subject.class.where(:friend_id => new_partner_for_friend).first
      new_partners_chat.user.should == friend
      new_partners_chat.friend.should == new_partner_for_friend
      new_partners_chat.active_users.should == [new_partner_for_friend]

      user.should_not be_currently_chatting
      friend.should_not be_currently_chatting
    end

    context "passing :active_user => #<User...A>" do
      context "and #<User...B> is not currently chatting with #<User...C>" do
        it "should only deactivate the chat for #<User...A> and leave #<User...B> active" do
          # so that they are available to chat with someone else
          active_chat.deactivate!(:active_user => user)
          active_chat.active_users.should == [friend]
        end
      end

      context "but #<User...B> is now currently chatting with #<User...C>" do
        before do
          active_chat_with_single_user
          create(:active_chat, :user => friend)
        end

        it "should deactivate the chat for both #<User...A> and #<User...B>" do
          # so that they are available to chat with someone else
          active_chat_with_single_user.deactivate!(:active_user => user)
          active_chat_with_single_user.active_users.should == []
        end
      end

      context ":notify => #<User...B>" do
        it "should inform User B how to start a new chat" do
          expect_message { active_chat.deactivate!(:active_user => user, :notify => friend) }
          reply_to_friend.body.should == spec_translate(
            :chat_has_ended, friend.locale
          )
          reply_to_user.should be_nil
        end
      end
    end

    context "passing :active_user => true" do
      context "given there are no replies for this chat" do
        before do
          active_chat.deactivate!(:active_user => true)
        end

        it "should deactivate the chat for both users" do
          active_chat.active_users.should be_empty
          active_chat.should_not be_active
        end
      end

      context "given there are replies for this chat" do
        before do
          create(:delivered_reply, :chat => active_chat, :user => user)
        end

        context "and the last reply was to the user" do
          before do
            active_chat.deactivate!(:active_user => true)
          end

          it "should deactivate the chat for the friend" do
            active_chat.active_users.should == [user]
          end
        end

        context "and the last reply was to the friend" do
          before do
            rep = create(:delivered_reply, :chat => active_chat, :user => friend)
            active_chat.deactivate!(:active_user => true)
          end

          it "should deactivate the chat for the user" do
            active_chat.active_users.should == [friend]
          end
        end
      end

      context "given there are undelivered messages for the deactivated users" do
        def setup_chat_reactivation_scenario(user, users_old_relationship)
          # create an old chat
          users_old_chat = users_old_relationship.is_a?(subject.class) ? users_old_relationship : send("active_chat_with_single_#{users_old_relationship}")

          # create an undelivered reply to the old chat
          message_from_old_friend = create(:reply, :user => user, :chat => users_old_chat, :body => "Hi buddy")

          # activate a new chat for the user
          chat_to_deactivate = create(:active_chat, :user => user)
          [users_old_chat, message_from_old_friend, chat_to_deactivate]
        end

        def assert_chat_reactivated(user, users_old_relationship, args = {})

          users_old_chat, message_from_old_friend, chat_to_deactivate = setup_chat_reactivation_scenario(
            user, users_old_relationship
          )

          # deactivate the new chat
          expect_message { chat_to_deactivate.deactivate!(args.merge(:notify => true)) }

          # assert the delivery of the message from the old friend
          message_from_old_friend.reload.should be_delivered

          # assert that the old chat has been reactivated
          users_old_chat.reload
          users_old_chat.should be_active

          reply_to(user).body.should == "Hi buddy"
        end

        def assert_chat_not_reactivated(user, users_old_relationship, args = {})
          users_old_chat, message_from_old_friend, chat_to_deactivate = setup_chat_reactivation_scenario(
            user, users_old_relationship
          )

          expect_message do
            chat_to_deactivate.deactivate!({:reactivate_previous_chat => false}.merge(args))
          end

          # assert the delivery of the message from the old friend
          message_from_old_friend.reload.should_not be_delivered

          # assert that the old chat has been reactivated
          users_old_chat.reload
          users_old_chat.should_not be_active
        end

        def assert_chat_reactivation(activate)
          assertion = "_not" unless activate
          send("assert_chat#{assertion}_reactivated", user, :friend, :active_user => true)
          send("assert_chat#{assertion}_reactivated", user, :friend, :active_user => user)
          send("assert_chat#{assertion}_reactivated", friend, :user, :active_user => friend)
          send("assert_chat#{assertion}_reactivated", friend, :user, :active_user => true)
        end

        it "should deliver the messages and reactivate the chats" do
          assert_chat_reactivation(true)
        end

        context "passing :reactivate_previous_chat => false" do
          it "should not deliver any messages or reactivate the chats" do
            assert_chat_reactivation(false)
          end
        end

        it "should not reactivate the chat if the initator in the old chat is logged out" do
          user.logout!
          assert_chat_not_reactivated(friend, chat, :active_user => true, :reactivate_previous_chat => true)
        end

        it "should not reactivate the chat if the friend in the old chat is logged out" do
          friend.logout!
          assert_chat_not_reactivated(user, chat, :active_user => true, :reactivate_previous_chat => true)
        end

        it "should not reactivate the chat if the initiator in the old chat is chatting with somebody else" do
          create(:active_chat, :user => user)
          assert_chat_not_reactivated(friend, chat, :active_user => true, :reactivate_previous_chat => true)
        end

        it "should not reactivate the chat if the friend in the old chat is is chatting with somebody else" do
          create(:active_chat, :friend => friend)
          assert_chat_not_reactivated(user, chat, :active_user => true, :reactivate_previous_chat => true)
        end
      end
    end

    context ":notify => true" do
      it "should inform both active users how to find a new friend" do
        expect_message { active_chat.deactivate!(:notify => true) }
        assert_active_users_cleared
        reply_to_user.body.should == spec_translate(:anonymous_chat_has_ended, user.locale)
        reply_to_friend.body.should == spec_translate(:anonymous_chat_has_ended, friend.locale)
      end
    end

    context ":notify => #<User...>" do
      it "should inform the user specified how to find a new friend" do
        expect_message { active_chat.deactivate!(:notify => friend) }
        assert_active_users_cleared
        reply_to_friend.body.should == spec_translate(:anonymous_chat_has_ended, friend.locale)
        reply_to_user.should be_nil
      end
    end

    context "passing no options" do
      it "should clear the active users" do
        active_chat.deactivate!
        assert_active_users_cleared
      end
    end
  end

  describe "#inactive_user" do
    it "should return the active user if he is the only active user in the chat" do
      active_chat_with_single_user.inactive_user.should == active_chat_with_single_user.user
      active_chat_with_single_friend.inactive_user.should == active_chat_with_single_friend.friend
      active_chat.inactive_user.should be_nil
      chat.inactive_user.should be_nil
    end
  end

  describe "#forward_message" do
    def create_message(user)
      create(:message, :user => user, :body => "hello")
    end

    let(:message) { create_message(user) }

    def assert_forward_message_to(recipient, originator, chat_session, message, delivered = true)
      chat_session.reload.messages.should == [message]
      reply = reply_to(recipient, chat_session)
      reply.body.should == spec_translate(
        :forward_message, recipient.locale, originator.screen_id, message.body
      )
      if delivered
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
    end

    context "given the friend is unavailable to chat" do
      def assert_new_friend_for_sender(recipient_name, unavailable_user)
        # create a new active chat for the unavailable user so they're unavailable
        create(:active_chat, :user => unavailable_user)

        recipient = send(recipient_name)
        chat_session = send("active_chat_with_single_#{recipient_name}")

        message = create_message(recipient)

        recipient.reload.active_chat.should == chat_session

        expect_message { chat_session.forward_message(message) }

        new_chat = recipient.reload.active_chat
        new_chat.should_not == chat_session

        if new_friend = new_chat.try(:friend)
          reply_to(new_chat.friend).body.should == spec_translate(:greeting_from_unknown_gender, new_friend.locale, recipient.screen_id)
        end

        reply_to(recipient).body.should == spec_translate(
          :friend_unavailable, recipient.locale, unavailable_user.screen_id
        )
        assert_forward_message_to(unavailable_user, recipient, chat_session, message, false)
      end

      it "should save the message for sending later and find new friends for the sender" do
        assert_new_friend_for_sender(:user, friend)
        assert_new_friend_for_sender(:friend, user)
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
          reply_to(new_friend).body.should == spec_translate(:greeting_from_unknown_gender, new_friend.locale, friend.screen_id)
        end
      end
    end
  end

  it_should_behave_like "filtering with communicable resources" do
    let(:resources) { [chat, unique_active_chat] }
  end

  describe ".filter_by" do
    it "should include users, friends & active users to avoid loading them for each user" do
      subject.class.filter_by.includes_values.should == [:user, :friend, :active_users]
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

  describe ".with_inactivity" do
    before do
      active_chat_with_inactivity
      unique_active_chat
      chat
      active_chat_with_single_user_with_inactivity
    end

    context "passing no options" do
      it "should return chats which have been inactive for more than 10 minutes" do
        subject.class.with_inactivity.should == [active_chat_with_inactivity, active_chat_with_single_user_with_inactivity]
      end
    end

    context "passing :active => true" do
      it "should return active chats which have been inactive for more than 10 minutes" do
        subject.class.with_inactivity(:active => true).should == [active_chat_with_inactivity]
      end
    end

    context "passing 11.minutes" do
      it "should return chats which have been inactive for more than 11 minutes" do
        subject.class.with_inactivity(:inactivity_period => 11.minutes).should == []
      end
    end
  end

  describe ".reactivate_stagnant!" do
    let(:chat_with_pending_messages) { create(:chat, :user => user) }
    let(:pending_reply) { create(:reply, :user => user, :chat => chat_with_pending_messages) }

    before do
      pending_reply
      chat_with_pending_messages
    end

    it "should reactivate stagnant chats" do
      chat_with_pending_messages.should_not be_active
      with_resque { expect_message { subject.class.reactivate_stagnant! } }
      chat_with_pending_messages.reload.should be_active
      pending_reply.reload.should be_delivered
    end

    it "should not reactivate stagnant chats if the users are not available" do
      active_chat
      with_resque { subject.class.reactivate_stagnant! }
      chat_with_pending_messages.reload.should_not be_active
      pending_reply.reload.should_not be_delivered
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

    context "passing no options" do
      before do
        expect_message { with_resque { subject.class.end_inactive } }
      end

      it "should deactivate chats with more than 10 minutes of inactivity" do
        active_chat_with_inactivity.should_not be_active
        active_chat_with_single_user_with_inactivity.active_users.count.should be_zero
      end

      it "should not notify the users that their chat has ended" do
        reply_to_user.should be_nil
        reply_to_friend.should be_nil
      end
    end

    context "passing :active => true" do
      before do
        expect_message { with_resque { subject.class.end_inactive(:active => true) } }
      end

      it "should deactivate active chats with more than 10 minutes of inactivity" do
        active_chat_with_inactivity.should_not be_active
        active_chat_with_single_user_with_inactivity.active_users.count.should == 1
      end
    end

    context "passing :inactivity_period => 11.minutes" do
      before do
        with_resque { subject.class.end_inactive(:inactivity_period => 11.minutes) }
      end

      it "should deactivate chats with more than 11 minutes of inactivity" do
        active_chat_with_inactivity.should be_active
      end
    end

    context "passing :notify => true" do
      before do
        with_resque { expect_message { subject.class.end_inactive(:notify => true) } }
      end

      it "should notify both users that their chat has ended" do
        reply_to(user, active_chat_with_inactivity).body.should == spec_translate(
          :anonymous_chat_has_ended, user.locale
        )
        reply_to(friend, active_chat_with_inactivity).body.should == spec_translate(
          :anonymous_chat_has_ended, friend.locale
        )
      end
    end

    context "passing any other options" do
      let(:other_options) { { :option_1 => :something, :option_2 => :something_else } }

      before do
        subject.class.stub(:find).and_return(active_chat_with_inactivity)
        active_chat_with_inactivity.stub(:deactivate!)
      end

      it "should pass the options onto #deactivate!" do
        active_chat_with_inactivity.should_receive(:deactivate!).with do |other_options|
          other_options.should == HashWithIndifferentAccess.new(other_options)
        end
        with_resque { subject.class.end_inactive({:inactivity_period => 10.minutes}.merge(other_options)) }
      end
    end
  end
end
