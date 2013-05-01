require 'spec_helper'

describe Locator do
  context "@queue" do
    it "should == :locator_queue" do
      subject.class.instance_variable_get(:@queue).should == :locator_queue
    end
  end

  describe ".perform(id, address)" do
    let(:location) { mock_model(Location) }
    let(:find_stub) { Location.stub(:find) }

    before do
      location.stub(:locate!)
      find_stub.with(1).and_return(location)
    end

    it "should tell the location to locate itself" do
      location.should_receive(:locate!).with("5 Park Lane")
      subject.class.perform(1, "5 Park Lane")
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [1, "5 Park Lane"] }
      let(:error_stub) { find_stub }
    end
  end
end
