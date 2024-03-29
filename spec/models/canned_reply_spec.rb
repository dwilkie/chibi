require 'rails_helper'

describe CannedReply do
  include PhoneCallHelpers::TwilioHelpers

  let(:sender) { create(:user, :female, :name => "bunheng") }
  let(:recipient) { create(:user) }
  let(:contact_me_number) { "2442" }
  let(:can_call_to_short_code) { false }

  subject { described_class.new(:kh, contact_me_number, can_call_to_short_code, :sender => sender, :recipient => recipient) }

  def assert_random(method, *args, &block)
    100.times do
      result = subject.send(method, *args)
      expect(result).not_to match(/[\%\{]+/)
      yield(result) if block_given?
    end
  end

  def assert_contact_number_included(result)
    expect(result).to match(/#{Regexp.escape(contact_me_number)}/)
  end

  describe "#gay_reminder" do
    context "for boys" do
      let(:recipient) { create(:user, :male, :name => "hanh") }
      it "should generate a gay reminder message for males" do
        assert_random(:gay_reminder) do |result|
          expect(result).to match(/boys/)
        end
      end
    end

    context "for girls" do
      let(:recipient) { create(:user, :female, :name => "hanh") }
      it "should generate a gay reminder message for females" do
        assert_random(:gay_reminder) do |result|
          expect(result).to match(/girls/)
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
          expect(result).to match(/(?:love|gay)/i)
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
      expect(result).to match(/sms/i)
      assert_contact_number_included(result)
    end

    def assert_call_me(result, positive_assertion = true)
      call_regex = /call/i
      positive_assertion ? (expect(result).to match(call_regex)) : (expect(result).not_to match(call_regex))
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
      let(:can_call_to_short_code) { true }

      it "should generate a 'sms or call me' message" do
        assert_random(:contact_me) do |result|
          assert_sms_me(result)
          assert_call_me(result)
        end
      end
    end
  end
end
