require 'spec_helper'

describe "Chatting" do
  include MessagingHelpers
  include TranslationHelpers

  include_context "existing users"
  include_context "replies"

  context "given I am in a chat session" do

    before do
      # ensure that joy is the first match by increasing her initiated chat count
      create(:chat, :user => joy)
      initiate_chat(dave)
    end

    context "and I text" do
      context "'new'" do
        before do
          send_message(:from => dave.mobile_number, :body => "new")
        end

        it "should end my current chat and start a new one" do
          replies[3].body.should == spec_translate(
            :new_chat_started,
            :old_friends_screen_name => joy.screen_id,
            :friends_screen_name => mara.screen_id,
            :users_name => dave.name,
            :locale => dave.locale
          )

          replies[3].to.should == dave.mobile_number
        end
      end

      context "'Hi knyom sok 27 nov kt want 2 chat with me? 012 232 234'" do
        before do
          send_message(:from => dave.mobile_number, :body => "Hi knyom sok 27 nov kt want 2 chat with me? 012 232 234")
          dave.reload
        end

        it "should not update my profile, but it should forward my message to my chat partner" do
          dave.name.should_not == "sok"
          dave.age.should_not == 27
          dave.location.city.should_not == "Kampong Thom"
          dave.mobile_number.should_not == "012232234"

          last_reply.body.should == "dave#{dave.id}: Hi knyom sok 27 nov kt want 2 chat with me? 012 232 234"
          last_reply.to.should == joy.mobile_number
        end
      end
    end

    context "and my partner texts" do
      context "'new'" do
        before do
          send_message(:from => joy.mobile_number, :body => "new")
        end

        it "should end my current chat and give me instructions on how to start a new one" do
          replies[2].body.should == spec_translate(
            :chat_has_ended,
            :missing_profile_attributes => [],
            :friends_screen_name => joy.screen_id,
            :locale => dave.locale
          )

          replies[2].to.should == dave.mobile_number
        end
      end

      context "'Hi Dave, knyom sara bong nov na?'" do
        before do
          send_message(:from => joy.mobile_number, :body => "Hi Dave, knyom sara bong nov na?")
          joy.reload
        end

        it "should not update her profile, but it should forward her message to me" do
          joy.name.should_not == "sara"

          last_reply.body.should == "#{joy.screen_id}: Hi Dave, knyom sara bong nov na?"
          last_reply.to.should == dave.mobile_number
        end
      end
    end
  end
end
