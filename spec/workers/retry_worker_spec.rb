require 'spec_helper'

describe RetryWorker do
  describe ".retry_exceptions" do
    it "should only be Redis::CommandError" do
      subject.class.retry_exceptions.should == [Redis::CommandError]
    end
  end

  describe ".retry_delay" do
    it "should be 0 (seconds) - don't use the scheduler doesn't work with HireFire just yet" do
      subject.class.retry_delay.should == 0
    end
  end

  describe ".retry_limit" do
    it "should be 5 (times)" do
      subject.class.retry_limit.should == 5
    end
  end
end
