require 'spec_helper'

describe Reply do
  include TranslationHelpers

  let(:user) { build(:user) }

  # add more users here as you get more languages
  let(:local_users) do
    [build(:cambodian), build(:english)]
  end

  let(:new_reply) { build(:reply, :user => user) }
  let(:partner) { build(:user_with_name) }

  def assert_reply(method, key, args = [], interpolations = [], test_users = nil)
    (test_users || local_users).each do |local_user|
      subject.user = local_user
      subject.send(method, *args)
      subject.body.should == spec_translate(key, local_user.locale, *interpolations)
    end
  end

  shared_examples_for "replying to a user" do
    before do
      subject.user = user
    end

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
    it_should_behave_like "replying to a user" do
      let(:method) { :logout_or_end_chat }
      let(:args) { [] }
    end

    context "passing no options" do
      it "should tell the user that their chat has ended" do
        assert_reply(:logout_or_end_chat, :anonymous_chat_has_ended)
      end
    end

    context ":logout => true" do
      it "should tell the user that they have been logged out" do
        assert_reply(:logout_or_end_chat, :anonymous_logged_out, [{:logout => true}])
      end

      context "given an english user is only missing their sexual preference" do
        # special case

        let(:english_user_only_missing_sexual_preference) do
          build(:english_user_with_complete_profile, :looking_for => nil)
        end

        it "should tell them to text in the gender they're seeking" do
          assert_reply(
            :logout_or_end_chat,
            :only_missing_sexual_preference_logged_out,
            [{:logout => true}],
            [],
            [english_user_only_missing_sexual_preference]
          )
        end
      end
    end
  end

  describe "#explain_chat_could_not_be_started" do
    it_should_behave_like "replying to a user" do
      let(:method) { :explain_chat_could_not_be_started }
      let(:args) { [] }
    end

    it "should tell the user that their chat could not be started at this time" do
      assert_reply(:explain_chat_could_not_be_started, :could_not_start_new_chat)
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
      assert_reply(
        :forward_message, :forward_message, ["mike", "hi how r u doing"], ["mike", "hi how r u doing"]
      )
    end
  end

  describe "introduce" do
    it_should_behave_like "replying to a user" do
      let(:method) { :introduce }
      let(:args) { [partner] }
    end

    it "should tell the user that someone is interested in chatting with them" do
      assert_reply(
        :introduce, :anonymous_new_chat_started, [partner], [partner.screen_id]
      )
    end
  end
end
