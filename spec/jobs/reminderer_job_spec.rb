require 'spec_helper'

describe RemindererJob do
  let(:options) { {"limit" => 300, "inactivity_period" => 24.hours.ago.to_s, "between" => [6, 24] } }
  subject { described_class.new(options) }

  it "should be serializeable" do
    expect(subject.serialize["arguments"].first).to eq(options)
  end

  describe "#queue_name" do
    it { expect(subject.queue_name).to eq("very_low") }
  end

  describe "#perform(options = {})" do
    before do
      allow(User).to receive(:remind!)
    end

    it "should remind users" do
      expect(User).to receive(:remind!).with(options)
      subject.perform(options)
    end
  end
end
