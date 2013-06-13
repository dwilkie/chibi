require 'spec_helper'

describe TwilioCdrFetcher do
  context "@queue" do
    it "should == :twilio_cdr_fetcher_queue" do
      subject.class.instance_variable_get(:@queue).should == :twilio_cdr_fetcher_queue
    end
  end

  describe ".perform(phone_call_id)" do
    let(:phone_call) { mock_model(PhoneCall) }
    let(:find_stub) { PhoneCall.stub(:find) }

    before do
      find_stub.and_return(phone_call)
    end

    it "should tell the phone call to fetch it's own CDR from Twilio" do
      phone_call.should_receive(:fetch_inbound_twilio_cdr!)
      phone_call.should_receive(:fetch_outbound_twilio_cdr!)
      subject.class.perform(1)
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [1] }
      let(:error_stub) { find_stub }
    end
  end
end
