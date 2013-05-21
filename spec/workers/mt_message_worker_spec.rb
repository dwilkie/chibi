require 'spec_helper'

describe MtMessageWorker do
  context "@queue" do
    it "should be nil" do
      subject.class.instance_variable_get(:@queue).should be_nil
    end
  end

  it "should not respond to .perform" do
    subject.class.should_not respond_to(:perform)
  end
end
