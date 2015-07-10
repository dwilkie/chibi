require 'rails_helper'

describe ReplyFixInvalidStatesScheduledJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:scheduled_queue]) }
  end

  describe "#perform" do
    before do
      allow(Reply).to receive(:fix_invalid_states!)
    end

    it "should fix invalid reply states" do
      expect(Reply).to receive(:fix_invalid_states!)
      subject.perform
    end
  end
end
