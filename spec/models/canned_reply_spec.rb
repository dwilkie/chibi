require 'spec_helper'

describe CannedReply do
  let(:sender) { create(:user, :female, :name => "bunheng") }
  let(:recipient) { create(:user) }

  subject { CannedReply.new(:kh, :sender => sender, :recipient => recipient) }

  def assert_no_missing_interpolations(&block)
    100.times do
      yield.should_not =~ /[\%\{]+/
    end
  end

  describe "#greeting" do
    it "should generate a random greeting" do
      assert_no_missing_interpolations { subject.greeting }
    end
  end

  describe "#call_me(on)" do
    it "should generate a 'call me' message" do
      assert_no_missing_interpolations { subject.call_me("2442") }
    end
  end
end
