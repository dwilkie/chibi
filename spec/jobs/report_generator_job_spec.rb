require 'rails_helper'

describe ReportGeneratorJob do
  let(:options) { ActionController::Parameters.new(:year => 2014, :month => 1) }
  subject { described_class.new(options) }

  it "should be serializeable" do
    expect(subject.serialize["arguments"].first).to include(options)
  end

  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:report_generator_queue]) }
  end

  describe "#perform(options)" do
    let(:report) { double(Report) }

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
