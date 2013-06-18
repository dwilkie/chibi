require 'spec_helper'

describe CannedReply do
  let(:sender) { create(:user, :female, :name => "bunheng") }
  let(:recipient) { create(:user) }

  subject { CannedReply.new(:kh, :sender => sender, :recipient => recipient) }

  describe "#greeting" do
    it "should generate a random greeting" do
      100.times do
        subject.greeting.should_not =~ /[\%\{]+/
      end
    end
  end
end
