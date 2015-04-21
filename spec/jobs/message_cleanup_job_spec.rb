require 'rails_helper'

describe MessageCleanupJob do
  it { expect(subject).to be_a(ActiveJob::Base) }

  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:message_cleanup_queue]) }
  end

  describe "#perform(message_id)" do
    let(:message_id) { 1 }
    let(:message) { double(Message) }

    before do
      allow(Message).to receive(:find_by_id).with(message_id).and_return(message)
      allow(message).to receive(:destroy_invalid_multipart!)
    end

    it "should ask the message to destroy itself" do
      expect(message).to receive(:destroy_invalid_multipart!)
      subject.perform(message_id)
    end
  end
end
