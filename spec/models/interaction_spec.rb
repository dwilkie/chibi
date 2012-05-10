require 'spec_helper'

describe Interaction do

  let(:params) { { :page => "1" } }
  let(:subject) { Interaction.new(params) }
  let(:message) { create(:message) }
  let(:reply) { create(:reply) }
  let(:phone_call) { create(:phone_call) }

  describe "#total_messages" do
    before do
      message
    end

    it "should return the total number of messages" do
      subject.total_messages.should == 1
    end
  end

  describe "#total_replies" do
    before do
      reply
    end

    it "should return the total number of replies" do
      subject.total_replies.should == 1
    end
  end

  describe "#total_phone_calls" do
    before do
      phone_call
    end

    it "should return the total number of replies" do
      subject.total_phone_calls.should == 1
    end
  end

  describe "#paginated_interactions" do
    let(:another_reply) { create(:reply) }

    before do
      message
      reply
      phone_call
      another_reply
    end

    it "should return the paginated interactions (for now just show replies)" do
      subject.paginated_interactions.should == [another_reply, reply]
    end
  end
end
