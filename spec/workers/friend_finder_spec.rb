require 'spec_helper'

describe FriendFinder do
  context "@queue" do
    it "should == :friend_finder_queue" do
      subject.class.instance_variable_get(:@queue).should == :friend_finder_queue
    end
  end

  describe ".perform(options = {})" do
    let!(:job_stub) { User.stub(:find_friends) }

    it "should find friends for users who need friends" do
      User.should_receive(:find_friends) do |options|
        options["some"].should == :options
        options[:some].should == :options
        options.should be_a(HashWithIndifferentAccess)
      end

      subject.class.perform(:some => :options)
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [{}] }
    end
  end
end
