require 'spec_helper'

describe RemindererJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq("reminderer_queue") }
  end

  describe "#perform(options = {})" do
    let(:options) { {"some" => :options} }

    before do
      allow(User).to receive(:remind!)
    end

    it "should remind users" do
      expect(User).to receive(:remind!).with(options)
      subject.perform(options)
    end
  end
end
