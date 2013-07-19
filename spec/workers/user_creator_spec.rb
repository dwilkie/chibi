require 'spec_helper'

describe UserCreator do
  context "@queue" do
    it "should == :user_creator_queue" do
      subject.class.instance_variable_get(:@queue).should == :user_creator_queue
    end
  end

  describe ".perform(mobile_number, metadata)" do
    let(:create_stub) { User.stub(:create_unactivated!) }
    let(:mobile_number) { "mobile_number" }
    let(:metadata) { {"some" => "data"} }

    before do
      create_stub
    end

    it "should create a new unactivated user" do
      User.should_receive(:create_unactivated!).with(mobile_number, metadata)
      subject.class.perform(mobile_number, metadata)
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [mobile_number, metadata] }
      let(:error_stub) { create_stub }
    end
  end
end
