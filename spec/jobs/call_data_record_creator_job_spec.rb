require 'spec_helper'

describe CallDataRecordCreatorJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq("very_high") }
  end

  describe "#perform(body)" do
    let(:call_data_record) { double(CallDataRecord) }
    let(:inbound_cdr) { double(InboundCdr) }
    let(:body) { "foo" }

    before do
      allow(CallDataRecord).to receive(:new).and_return(call_data_record)
      allow(call_data_record).to receive(:typed).and_return(inbound_cdr)
      allow(inbound_cdr).to receive(:save!)
    end

    it "should create the CDR" do
      expect(CallDataRecord).to receive(:new).with(:body => body)
      expect(inbound_cdr).to receive(:save!)
      subject.perform(body)
    end
  end
end
