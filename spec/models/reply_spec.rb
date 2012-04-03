require 'spec_helper'

describe Reply do
  include TranslationHelpers
  include MessagingHelpers

  let(:user) { build(:user) }

  # add more users here as you get more languages
  let(:local_users) do
    [build(:cambodian), build(:english)]
  end

  let(:new_reply) { build(:reply, :user => user) }
  let(:partner) { build(:user_with_name) }
  let(:reply) { create(:reply, :user => user) }

  def assert_reply(method, key, args = [], interpolations = [], test_users = nil)
    (test_users || local_users).each do |local_user|
      subject.user = local_user
      expect_message { subject.send(method, *args) }
      subject.body.should == spec_translate(key, local_user.locale, *interpolations)
    end
  end

  shared_examples_for "replying to a user" do
    before do
      subject.user = user
      expect_message do
        subject.send(method, *args)
      end
    end

    it "should persist the reply" do
      subject.should be_persisted
    end

    it "should set the destination to the user's mobile number" do
      subject.destination.should == user.mobile_number
    end

    it "should send the reply" do
      FakeWeb.last_request.path.should == "/#{ENV["NUNTIUM_ACCOUNT"]}/#{ENV["NUNTIUM_APPLICATION"]}/send_ao.json"
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

  describe ".filter_by" do
    let(:another_reply) { create(:reply) }

    before do
      expect_message do
        another_reply
        reply
      end
    end

    context "passing no params" do
      it "should return all replies ordered by latest created at date" do
        subject.class.filter_by.should == [reply, another_reply]
      end
    end

    context ":user_id => 2" do
      it "should return all replies with the given user id" do
        subject.class.filter_by(:user_id => user.id).should == [reply]
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

    context "passing partner" do
      it "should inform the user how to find a new friend" do
        assert_reply(:logout_or_end_chat, :anonymous_chat_has_ended, [partner], [partner.screen_id])
      end
    end

    context "passing no partner" do
      it "should tell the user that they have been logged out" do
        assert_reply(:logout_or_end_chat, :anonymous_logged_out)
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
            [],
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

  describe "#introduce" do
    it_should_behave_like "replying to a user" do
      let(:method) { :introduce }
      let(:args) { [partner, true] }
    end

    context "for the chat initiator" do
      it "should tell her that we have found a friend for her" do
        assert_reply(
          :introduce, :anonymous_new_friend_found, [partner, true], [partner.screen_id]
        )
      end
    end

    context "for the chat partner" do
      it "should tell him that someone is interested in chatting with him" do
        assert_reply(
          :introduce, :anonymous_new_chat_started, [partner, false], [partner.screen_id]
        )
      end
    end
  end

  describe "#welcome" do
    it_should_behave_like "replying to a user" do
      let(:method) { :welcome }
      let(:args) { [] }
    end

    it "should welcome the user" do
      assert_reply(:welcome, :welcome)
    end
  end
end
