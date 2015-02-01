require 'rails_helper'

describe Interaction do

  let(:params) { { :page => "1" } }
  let(:subject) { Interaction.new(params) }
  let(:message) { create(:message) }
  let(:reply) { create(:reply) }
  let(:phone_call) { create(:phone_call) }

  describe "#paginated_interactions" do
    let(:another_reply) { create(:reply) }

    before do
      message
      reply
      phone_call
      another_reply
    end

    it "should return the paginated interactions" do
      subject.paginated_interactions.should == [message, phone_call]
    end
  end
end
