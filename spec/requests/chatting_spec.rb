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
          reply_to(dave).body.should == spec_translate(
            :personalized_old_chat_ended_new_chat_started,
            dave.locale, dave.name.capitalize, joy.screen_id, mara.screen_id,
          )
        end
      end

      context "'stop'" do
        before do
          send_message(:from => dave.mobile_number, :body => "stop")
        end

        it "should end my current chat and log me out" do
          reply_to(dave).body.should == spec_translate(
            :logged_out_and_chat_has_ended, dave.locale, joy.screen_id
          )
        end
      end

      context "'Hi knyom sok 27 nov kt want 2 chat with me? 012 232 234'" do
        before do
          send_message(:from => dave.mobile_number, :body => "Hi knyom sok 27 nov kt want 2 chat with me? 012 232 234")
          dave.reload
        end

        it "should forward my message to my chat partner" do
          dave.name.should_not == "sok"
          dave.age.should_not == 27
          dave.location.city.should_not == "Kampong Thom"
          dave.mobile_number.should_not == "012232234"
          reply_to(joy).body.should == "dave#{dave.id}: Hi knyom sok 27 nov kt want 2 chat with me? 012 232 234"
        end
      end
    end

    context "and my partner texts" do

      shared_examples_for "ending my current chat" do
        it "should end my current chat and give me instructions on how to start a new one" do
          reply_to(dave).body.should == spec_translate(
            :chat_has_ended, dave.locale, joy.screen_id
          )
        end
      end

      context "'new'" do
        before do
          send_message(:from => joy.mobile_number, :body => "new")
        end

        it_should_behave_like "ending my current chat"
      end

      context "'stop'" do
        before do
          send_message(:from => joy.mobile_number, :body => "stop")
        end

        it_should_behave_like "ending my current chat"
      end

      context "'Hi Dave, knyom sara bong nov na?'" do
        before do
          send_message(:from => joy.mobile_number, :body => "Hi Dave, knyom sara bong nov na?")
          joy.reload
        end

        it "should forward her message to me" do
          joy.name.should_not == "sara"
          reply_to(dave).body.should == "#{joy.screen_id}: Hi Dave, knyom sara bong nov na?"
        end
      end
    end
  end
end
