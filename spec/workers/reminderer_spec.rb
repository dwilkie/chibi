require 'spec_helper'

describe Reminderer do
  context "@queue" do
    it "should == :reminderer" do
      subject.class.instance_variable_get(:@queue).should == :reminderer_queue
    end
  end

  describe ".perform(options = {})" do
    let!(:job_stub) { User.stub(:remind!) }

    it "should remind users" do
      User.should_receive(:remind!) do |options|
        options["some"].should == :options
        options[:some].should == :options
        options.should be_a(HashWithIndifferentAccess)
      end
      subject.class.perform(:some => :options)
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [{}] }
      let(:error_stub) { job_stub }
    end
  end
end
