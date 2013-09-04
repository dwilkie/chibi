require 'spec_helper'

describe ReportGenerator do
  context "@queue" do
    it "should == :report_generator_queue" do
      subject.class.instance_variable_get(:@queue).should == :report_generator_queue
    end
  end

  describe ".perform(options = {})" do
    let(:report) { double(Report) }
    let(:error_stub) { report.stub(:generate!) }

    before do
      Report.stub(:new).and_return(report)
    end

    it "should generate a report" do
      Report.should_receive(:new) do |options|
        options["some"].should == :options
        options[:some].should == :options
        options.should be_a(HashWithIndifferentAccess)
        report
      end
      report.should_receive(:generate!)
      subject.class.perform(:some => :options)
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [{}] }
    end
  end
end
