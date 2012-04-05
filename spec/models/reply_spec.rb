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

  def assert_persisted_and_delivered(reply, mobile_number, options = {})
    options[:deliver] = true unless options[:deliver] == false
    reply.should be_persisted
    reply.destination.should == mobile_number
    last_request = FakeWeb.last_request
    if options[:deliver]
      last_request.path.should == "/#{ENV["NUNTIUM_ACCOUNT"]}/#{ENV["NUNTIUM_APPLICATION"]}/send_ao.json"
      JSON.parse(last_request.body).first["body"].should == reply.body
      reply.should be_delivered
    else
      reply.should_not be_delivered
    end
  end

  def assert_reply(method, key, options = {})
    options[:args] ||= []
    options[:interpolations] || []
    (options[:test_users] || local_users).each do |local_user|
      reply = subject.class.new
      reply.user = local_user
      expect_message { reply.send(method, *options[:args]) }
      reply.body.should == spec_translate(key, local_user.locale, *options[:interpolations])
      assert_persisted_and_delivered(reply, local_user.mobile_number, options)
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

  describe ".undelivered" do
    let(:delivered_reply) { create(:delivered_reply) }

    before do
      reply
      delivered_reply
    end

    it "should return only the undelivered replies" do
      subject.class.undelivered.should == [reply]
    end
  end

  describe ".delivered" do
    let(:delivered_reply) { create(:delivered_reply) }

    before do
      reply
      delivered_reply
    end

    it "should return only the delivered replies" do
      subject.class.delivered.should == [delivered_reply]
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

  describe "#delivered?" do
    it "should return true if the message has been delivered" do
      reply.should_not be_delivered
      expect_message { reply.deliver! }
      reply.should be_delivered
    end
  end

  describe "#deliver!" do
    it "should deliver the message" do
      expect_message { new_reply.deliver! }
      assert_persisted_and_delivered(new_reply, user.mobile_number)
    end
  end

  describe "#end_chat!" do
    it "should inform the user how to find a new friend" do
      method = :end_chat!
      args = [partner]
      interpolations = [partner.screen_id]

      assert_reply(method, :anonymous_chat_has_ended, :args => args, :interpolations => interpolations)
      args << {:skip_update_profile_instructions => true}
      assert_reply(method, :chat_has_ended, :args => args, :interpolations => interpolations)
    end
  end

  describe "#logout!" do
    it "should confirm the user that they have been logged out and explain how to find a new friend" do
      assert_reply(:logout!, :anonymous_logged_out)
      assert_reply(:logout!, :logged_out_from_chat, :args => [partner], :interpolations => [partner.screen_id])
    end

    context "given an english user is only missing their sexual preference" do
      # special case

      let(:english_user_only_missing_sexual_preference) do
        build(:english_user_with_complete_profile, :looking_for => nil)
      end

      it "should tell them to text in the gender they're seeking" do
        assert_reply(
          :logout!,
          :only_missing_sexual_preference_logged_out,
          :test_users => [english_user_only_missing_sexual_preference]
        )
      end
    end
  end

  describe "#explain_chat_could_not_be_started!" do
    it "should tell the user that their chat could not be started at this time" do
      assert_reply(:explain_chat_could_not_be_started!, :could_not_start_new_chat)
    end
  end

  describe "#explain_friend_is_unavailable!" do
    it "should inform the user that their friend is unavailable and explain how to meet a new friend" do
      assert_reply(
        :explain_friend_is_unavailable!, :friend_unavailable,
        :args => [partner], :interpolations => [partner.screen_id]
      )
    end
  end

  describe "#forward_message" do
    it "should show the message in a chat context but not deliver the message" do
      assert_reply(
        :forward_message, :forward_message,
        :args => ["mike", "hi how r u doing"], :interpolations => ["mike", "hi how r u doing"],
        :deliver => false
      )
    end
  end

  describe "#forward_message!" do
    it "should deliver the forwarded message" do
      assert_reply(
        :forward_message!, :forward_message,
        :args => ["mike", "hi how r u doing"], :interpolations => ["mike", "hi how r u doing"],
      )
    end
  end

  describe "#introduce!" do

    context "for the chat initiator" do
      it "should tell her that we have found a friend for her" do
        assert_reply(
          :introduce!, :anonymous_new_friend_found,
          :args => [partner, true], :interpolations => [partner.screen_id]
        )
      end
    end

    context "for the chat partner" do
      it "should tell him that someone is interested in chatting with him" do
        assert_reply(
          :introduce!, :anonymous_new_chat_started,
          :args => [partner, false], :interpolations => [partner.screen_id]
        )
      end
    end
  end

  describe "#welcome!" do
    it "should welcome the user" do
      assert_reply(:welcome!, :welcome)
    end
  end
end
