require 'spec_helper'

describe ReportGeneratorJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq("high") }
  end

  describe "#perform(options)" do
    let(:report) { double(Report) }
    let(:options) { ActionController::Parameters.new(:some => :options) }

    before do
      allow(Report).to receive(:new).and_return(report)
      allow(report).to receive(:generate!)
    end

    it "should generate a report" do
      expect(Report).to receive(:new).with(options)
      expect(report).to receive(:generate!)
      subject.perform(options)
    end
  end
end
