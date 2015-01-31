require 'spec_helper'

describe MtMessageSenderJob do
  it "should be a type of ActiveJob" do
    expect(subject).to be_a(ActiveJob::Base)
  end
end
