require 'spec_helper'

describe UserImporter do
  context "@queue" do
    it "should == :user_importer_queue" do
      subject.class.instance_variable_get(:@queue).should == :user_importer_queue
    end
  end

  describe ".perform(data)" do
    let(:import_stub) { User.stub(:import!) }
    let(:data) { { "some" => "data" } }

    before do
      import_stub
    end

    it "should import the data" do
      User.should_receive(:import!).with(data)
      subject.class.perform(data)
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [data] }
    end
  end
end
