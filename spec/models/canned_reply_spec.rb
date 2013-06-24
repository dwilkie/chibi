require 'spec_helper'

describe CannedReply do
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

  describe "#greeting" do
    it "should generate a random greeting" do
      assert_random(:greeting)
    end
  end

  describe "#call_me(on)" do
    def assert_sms_me(result)
      result.should =~ /sms/i
    end

    def assert_call_me(result, positive_assertion = true)
      call_regex = /call/i
      positive_assertion ? result.should =~ call_regex : result.should_not =~ call_regex
    end

    context "the recipient's operator does not have voice enabled" do
      it "should generate a 'sms me' message" do
        assert_random(:call_me, "2442") do |result|
          assert_sms_me(result)
          assert_call_me(result, false)
        end
      end
    end

    context "the recipient's operator has voice enabled" do
      let(:recipient) { create(:user, :from_operator_with_voice) }

      it "should generate a 'sms or call me' message" do
        assert_random(:call_me, "2442") do |result|
          assert_sms_me(result)
          assert_call_me(result)
        end
      end
    end
  end
end
