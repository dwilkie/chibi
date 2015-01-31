require 'spec_helper'

describe ChatExpirerJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq("default") }
  end

  describe "#perform(options = {})" do
    let(:options) { {"some" => :options} }

    before do
      allow(Chat).to receive(:end_inactive)
    end

    it "should end inactive chats" do
      expect(Chat).to receive(:end_inactive).with(options)
      subject.perform(options)
    end
  end
end
