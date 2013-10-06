require 'spec_helper'

describe FriendMessenger do
  context "@queue" do
    it "should == :friend_messenger_queue" do
      subject.class.instance_variable_get(:@queue).should == :friend_messenger_queue
    end
  end

  describe ".perform(user_id, options = {})" do
    let(:user) { mock_model(User) }
    let(:find_stub) { User.stub(:find) }

    before do
      user.stub(:find_friends!)
      find_stub.and_return(user)
    end

    it "should find new friends for the user" do
      user.should_receive(:find_friends!) do |options|
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
