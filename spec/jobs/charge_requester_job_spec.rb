require 'spec_helper'

describe ChargeRequesterJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq("charge_requester_queue") }
  end

  it "should be a type of ActiveJob::Base" do
    expect(subject).to be_a(ActiveJob::Base)
  end
end
