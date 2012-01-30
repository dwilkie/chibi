require 'spec_helper'

describe "Chatting" do
  include MessagingHelpers
  include TranslationHelpers

  include_context "existing users"
  include_context "replies"

  context "given I am in a chat session" do
    before do
      initiate_chat(dave)
    end

    context "and I text" do
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
          last_reply.to.should == mara.mobile_number
        end
      end
    end

    context "and my partner texts" do
      context "'Hi Dave, knyom sara bong nov na?'" do
        before do
          send_message(:from => mara.mobile_number, :body => "Hi Dave, knyom sara bong nov na?")
          mara.reload
        end

        it "should not update her profile, but it should forward her message to me" do
          mara.name.should_not == "sara"

          last_reply.body.should == "mara#{mara.id}: Hi Dave, knyom sara bong nov na?"
          last_reply.to.should == dave.mobile_number
        end
      end
    end
  end
end
