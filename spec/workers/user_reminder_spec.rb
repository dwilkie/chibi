require 'spec_helper'

describe UserReminder do

  context "@queue" do
    it "should == :user_reminder_queue" do
      subject.class.instance_variable_get(:@queue).should == :user_reminder_queue
    end
  end

  describe ".perform" do
    let(:user) { mock_model(User) }
    before do
      user.stub(:remind!)
      User.stub(:find).and_return(user)
    end

    it "should tell the user to remind itself" do
      user.should_receive(:remind!)
      subject.class.perform(1)
    end
  end
end
