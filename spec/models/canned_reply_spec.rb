require 'rails_helper'

describe CannedReply do
  include PhoneCallHelpers::TwilioHelpers

  let(:sender) { create(:user, :female, :name => "bunheng") }
  let(:recipient) { create(:user) }

  subject { CannedReply.new(:kh, :sender => sender, :recipient => recipient) }

  def assert_random(method, *args, &block)
    100.times do
      result = subject.send(method, *args)
      result.should_not =~ /[\%\{]+/
      yield(result) if block_given?
    end
  end

  def assert_contact_number_included(result)
    result.should =~ /#{Regexp.escape(recipient.contact_me_number)}/
  end

  describe "#gay_reminder" do
    context "for boys" do
      let(:recipient) { create(:user, :male, :name => "hanh") }
      it "should generate a gay reminder message for males" do
        assert_random(:gay_reminder) do |result|
          result.should =~ /boys/
        end
      end
    end

    context "for girls" do
      let(:recipient) { create(:user, :female, :name => "hanh") }
      it "should generate a gay reminder message for females" do
        assert_random(:gay_reminder) do |result|
          result.should =~ /girls/
        end
      end
    end
  end

  describe "#greeting" do
    it "should generate a random greeting" do
      assert_random(:greeting)
    end

    context "passing :gay => true" do
      it "should generate a greeting aimed at gay users" do
        assert_random(:greeting, :gay => true) do |result|
          result.should =~ /(?:love|gay)/i
        end
      end
    end
  end

  describe "#follow_up(options)" do
    context "passing :to => :caller, :after => :conversation" do
      it "should should generate a canned message suitable for the caller after a conversation" do
        assert_random(:follow_up, :to => :caller, :after => :conversation)
      end
    end

    context "passing :to => :called_user, :after => :conversation" do
      it "should should generate a canned message suitable for the called user after a conversation" do
        assert_random(:follow_up, :to => :called_user, :after => :conversation)
      end
    end

    context "passing :to => :user, :after => :short_conversation" do
      it "should should generate a canned message suitable for the caller user after a short conversation" do
        assert_random(:follow_up, :to => :caller, :after => :short_conversation)
      end
    end

    context "passing :to => :called_user, :after => :short_conversation" do
      it "should should generate a canned message suitable for the called user after a short conversation" do
        assert_random(:follow_up, :to => :called_user, :after => :short_conversation)
      end
    end
  end

  describe "#contact_me" do
    def assert_sms_me(result)
      result.should =~ /sms/i
      assert_contact_number_included(result)
    end

    def assert_call_me(result, positive_assertion = true)
      call_regex = /call/i
      positive_assertion ? result.should =~ call_regex : result.should_not =~ call_regex
    end

    context "the recipient's operator does not have voice enabled" do
      it "should generate a 'sms me' message" do
        assert_random(:contact_me) do |result|
          assert_sms_me(result)
          assert_call_me(result, false)
        end
      end
    end

    context "the recipient's operator has voice enabled" do
      let(:recipient) { create(:user, :from_operator_with_voice) }

      it "should generate a 'sms or call me' message" do
        assert_random(:contact_me) do |result|
          assert_sms_me(result)
          assert_call_me(result)
        end
      end
    end
  end
end
