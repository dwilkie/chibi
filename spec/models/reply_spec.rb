require 'spec_helper'

describe Reply do
  include TranslationHelpers

  let(:user) { build(:user) }
  let(:new_reply) { build(:reply, :user => user) }
  let(:partner) { build(:user_with_name) }

  shared_examples_for "replying to a user" do
    it "should persist the reply" do
      subject.send(method, *args)
      subject.should be_persisted
    end

    it "should set the destination to the user's mobile number" do
      subject.send(method, *args)
      subject.destination.should == user.mobile_number
    end
  end

  describe "factory" do
    it "should be valid" do
      new_reply.should be_valid
    end
  end

  it "should not be valid without a user" do
    new_reply.user = nil
    new_reply.should_not be_valid
  end

  it "should not be valid without a destination" do
    new_reply.to = nil
    user.mobile_number = nil
    new_reply.should_not be_valid
  end

  describe "callbacks" do
    describe "when saving the reply" do
      context "if the destination is nil" do
        before do
          new_reply.destination = nil
        end

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

  describe "#logout_or_end_chat" do
    before do
      subject.user = user
    end

    it_should_behave_like "replying to a user" do
      let(:method) { :logout_or_end_chat }
      let(:args) { [] }
    end

    context "passing no options" do
      before do
        subject.logout_or_end_chat
      end

      it "should tell the user that their chat has ended" do
        subject.body.should == spec_translate(
          :logged_out_or_chat_has_ended,
          :missing_profile_attributes => user.missing_profile_attributes,
          :locale => user.locale
        )
      end
    end

    context ":partner => #<User...>" do
      it "should use the partners name in the reply" do
        subject.logout_or_end_chat(:partner => partner)

        subject.body.should == spec_translate(
          :logged_out_or_chat_has_ended,
          :friends_screen_name => partner.screen_id,
          :missing_profile_attributes => user.missing_profile_attributes,
          :locale => user.locale
        )
      end

      context ":logout => true" do
        it "should tell the user that their chat has ended and they have been logged out" do
          subject.logout_or_end_chat(:partner => partner, :logout => true)

          subject.body.should == spec_translate(
            :logged_out_or_chat_has_ended,
            :missing_profile_attributes => user.missing_profile_attributes,
            :friends_screen_name => partner.screen_id,
            :logged_out => true,
            :locale => user.locale
          )
        end
      end
    end

    context ":logout => true" do
      before do
        subject.logout_or_end_chat(:logout => true)
      end

      it "should tell the user that they have been logged out" do
        subject.body.should == spec_translate(
          :logged_out_or_chat_has_ended,
          :missing_profile_attributes => user.missing_profile_attributes,
          :logged_out => true,
          :locale => user.locale
        )
      end
    end
  end

  describe "#explain_chat_could_not_be_started" do
    before do
      subject.user = user
    end

    it_should_behave_like "replying to a user" do
      let(:method) { :explain_chat_could_not_be_started }
      let(:args) { [] }
    end

    it "should tell the user that their chat could not be started at this time" do
      subject.explain_chat_could_not_be_started

      subject.body.should == spec_translate(
        :could_not_start_new_chat,
        :users_name => user.name,
        :locale => user.locale
      )
    end
  end

  describe "#forward_message" do
    before do
      subject.user = user
    end

    it_should_behave_like "replying to a user" do
      let(:method) { :forward_message }
      let(:args) { ["mike", "hi how r u doing"] }
    end

    it "should show the message in a chat context" do
      subject.forward_message("mike", "hi how r u doing")
      subject.body.should == "mike: hi how r u doing"
    end
  end

  describe "introduce" do
    before do
      subject.user = user
    end

    it_should_behave_like "replying to a user" do
      let(:method) { :introduce }
      let(:args) { [partner] }
    end

    context "passing no options" do
      before do
        subject.introduce(partner)
      end

      it "should tell the user that someone is interested in chatting with them" do
        subject.body.should == spec_translate(
          :new_chat_started,
          :friends_screen_name => partner.screen_id,
          :users_name => user.name,
          :locale => user.locale
        )
      end
    end

    context ":to_user => true" do
      before do
        subject.introduce(partner, :to_user => true)
      end

      it "should introduce the user to his new partner" do
        subject.body.should == spec_translate(
          :new_chat_started,
          :friends_screen_name => partner.screen_id,
          :users_name => user.name,
          :to_user => true,
          :locale => user.locale
        )
      end
    end

    context ":to_user => true, :old_friends_screen_name => mikey013" do
      before do
        subject.introduce(partner, :to_user => true, :old_friends_screen_name => "mikey013")
      end

      it "should introduce the user to his new partner" do
        subject.body.should == spec_translate(
          :new_chat_started,
          :friends_screen_name => partner.screen_id,
          :old_friends_screen_name => "mikey013",
          :users_name => user.name,
          :to_user => true,
          :locale => user.locale
        )
      end
    end
  end
end
