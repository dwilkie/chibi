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

  describe "#activate!" do
    shared_examples_for "activating a chat" do
      it "should set the active users and save the chat" do
        reference_chat.activate!
        reference_chat.should be_active
        reference_chat.should be_persisted
        user.active_chat.should == reference_chat
        friend.active_chat.should == reference_chat
      end

      context "passing :notify => true" do
        it "should introduce the new chat participants" do
          expect_message { reference_chat.activate!(:notify => true) }
          reply_to(user, reference_chat).body.should == spec_translate(
            :anonymous_new_chat_started, user.locale, friend.screen_id
          )

          reply_to(friend, reference_chat).body.should == spec_translate(
            :anonymous_new_chat_started, friend.locale, user.screen_id
          )
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
      let(:current_active_chat)  { create(:active_chat, :user => user, :friend => current_chat_partner) }

      before do
        current_active_chat
      end

      it "should deactivate the other chat" do
        new_chat.activate!
        current_active_chat.should_not be_active
      end

      context "passing :notify => true" do
        it "should notify the current chat partner the chat has ended" do
          expect_message { new_chat.activate!(:notify => true) }
          reply_to(current_chat_partner, current_active_chat).body.should == spec_translate(
            :anonymous_chat_has_ended, current_chat_partner.locale
          )
          reply_to(user, current_active_chat).should be_nil
        end
      end

      context "passing no options" do
        it "should not notify the current chat partner the chat has ended" do
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
            reply_to(user).body.should == spec_translate(:could_not_start_new_chat, user.locale)
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

  describe "#deactivate!" do
    it "should clear the active users" do
      active_chat.deactivate!
      active_chat.active_users.should be_empty
      active_chat.should_not be_active
      active_chat.replies.should be_empty
    end

    context ":notify => true" do
      it "should notify both active users the the chat has ended" do
        expect_message { active_chat.deactivate!(:notify => true) }
        reply_to_user.body.should == spec_translate(:anonymous_chat_has_ended, user.locale)
        reply_to_friend.body.should == spec_translate(:anonymous_chat_has_ended, friend.locale)
      end
    end

    context ":notify => #<User...>" do
      it "should notify the user specified that the chat has ended" do
        expect_message { active_chat.deactivate!(:notify => friend) }
        reply_to_friend.body.should == spec_translate(:anonymous_chat_has_ended, friend.locale)
        reply_to_user.should be_nil
      end
    end
  end

  describe "#forward_message" do
    it "should foward the message to the chat partner" do
      expect_message { active_chat.forward_message(user, "hello friend") }

      active_chat.replies.count.should == 1
      reply_to_friend.body.should == spec_translate(:forward_message, friend.locale, user.screen_id, "hello friend")
    end

    it "should touch the chat" do
      active_chat_with_inactivity
      Timecop.freeze(Time.now) do
        expect_message {active_chat_with_inactivity.forward_message(user, "hello friend") }
        active_chat_with_inactivity.updated_at.should == Time.now
      end
    end
  end

  describe "#introduce_participants" do
    it "should send an introduction to both participants" do
      expect_message { active_chat.introduce_participants }

      reply_to_user.body.should == spec_translate(:anonymous_new_chat_started, user.locale, friend.screen_id)
      reply_to_friend.body.should == spec_translate(:anonymous_new_chat_started, friend.locale, user.screen_id)
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

  describe ".with_inactivity" do
    before do
      active_chat_with_inactivity
      unique_active_chat
      chat
    end

    context "passing no options" do
      it "should return active chats which have been inactive for more than 10 minutes" do
        subject.class.with_inactivity.should == [active_chat_with_inactivity]
      end
    end

    context "passing 11.minutes" do
      it "should return active chats which have been inactive for more than 11 minutes" do
        subject.class.with_inactivity(11.minutes).should == []
      end
    end
  end

  describe ".end_inactive" do
    before do
      chat.should_not be_active
      unique_active_chat.should be_active
      active_chat_with_inactivity.should be_active
    end

    after do
      chat.should_not be_active
      unique_active_chat.should be_active
    end

    context "passing no options" do
      before do
        with_resque { subject.class.end_inactive }
      end

      it "should deactivate active chats with more than 10 minutes of inactivity" do
        active_chat_with_inactivity.should_not be_active
      end

      it "should not notify the users that their chat has ended" do
        reply_to_user.should be_nil
        reply_to_friend.should be_nil
      end
    end

    context "passing :inactivity_period => 11.minutes" do
      before do
        with_resque { subject.class.end_inactive(:inactivity_period => 11.minutes) }
      end

      it "should deactivate active chats with more than 11 minutes of inactivity" do
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
