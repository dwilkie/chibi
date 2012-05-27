require 'spec_helper'

describe UserReminder do

  context "@queue" do
    it "should == :user_reminder_queue" do
      subject.class.instance_variable_get(:@queue).should == :user_reminder_queue
    end
  end

  describe ".perform" do
    before do
      User.stub(:remind!)
    end

    it "should remind inactive users" do
      User.should_receive(:remind!) do |options|
        options["some"].should == :options
        options[:some].should == :options
        options.should be_a(HashWithIndifferentAccess)
      end

      subject.class.perform(:some => :options)
    end
  end
end
