require 'spec_helper'

describe UserReminderer do
  context "@queue" do
    it "should == :user_reminderer_queue" do
      subject.class.instance_variable_get(:@queue).should == :user_reminderer_queue
    end
  end

  describe ".perform(user_id, options = {})" do
    let(:user) { mock_model(User) }
    let(:find_stub) { User.stub(:find) }

    before do
      user.stub(:remind!)
      find_stub.and_return(user)
    end

    it "should tell the user to remind himself" do
      user.should_receive(:remind!) do |options|
        options["some"].should == :options
        options[:some].should == :options
        options.should be_a(HashWithIndifferentAccess)
      end
      subject.class.perform(1, :some => :options)
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [1, {}] }
    end
  end
end
