require 'spec_helper'

describe InvalidNamePurger do

  context "@queue" do
    it "should == :invalid_name_purger_queue" do
      subject.class.instance_variable_get(:@queue).should == :invalid_name_purger_queue
    end
  end

  describe ".perform" do
    before do
      User.stub(:purge_invalid_names!)
    end

    it "should purge invalid names" do
      User.should_receive(:purge_invalid_names!)
      subject.class.perform
    end
  end
end
