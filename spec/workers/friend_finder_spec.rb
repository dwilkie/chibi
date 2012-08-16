require 'spec_helper'

describe FriendFinder do

  context "@queue" do
    it "should == :friend_finder_queue" do
      subject.class.instance_variable_get(:@queue).should == :friend_finder_queue
    end
  end

  describe ".perform" do
    before do
      User.stub(:find_friends)
    end

    it "should find friends for users who need friends" do
      User.should_receive(:find_friends) do |options|
        options["some"].should == :options
        options[:some].should == :options
        options.should be_a(HashWithIndifferentAccess)
      end

      subject.class.perform(:some => :options)
    end
  end
end
