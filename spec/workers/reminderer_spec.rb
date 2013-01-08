require 'spec_helper'

describe Reminderer do

  context "@queue" do
    it "should == :reminderer" do
      subject.class.instance_variable_get(:@queue).should == :reminderer_queue
    end
  end

  describe ".perform" do
    it "should remind users" do
      User.should_receive(:remind!) do |options|
        options["some"].should == :options
        options[:some].should == :options
        options.should be_a(HashWithIndifferentAccess)
      end
      subject.class.perform(:some => :options)
    end
  end
end
