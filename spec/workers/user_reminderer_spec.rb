require 'spec_helper'

describe UserReminderer do

  context "@queue" do
    it "should == :user_reminderer_queue" do
      subject.class.instance_variable_get(:@queue).should == :user_reminderer_queue
    end
  end

  describe ".perform" do
    let(:user) { mock_model(User) }
    before do
      user.stub(:remind!)
      User.stub(:find).and_return(user)
    end

    it "should tell the user to remind himself" do
      user.should_receive(:remind!) do |options|
        options["some"].should == :options
        options[:some].should == :options
        options.should be_a(HashWithIndifferentAccess)
      end
      subject.class.perform(1, :some => :options)
    end
  end
end
