require 'spec_helper'

describe Overview do
  let(:options) { { :some => :option } }

  describe "#new_users" do
    it "should return the overview of all new users" do
      User.should_receive(:overview_of_created).with(options)
      subject.new_users(options)
    end
  end

  describe "#messages_received" do
    it "should return the overview of all messages received" do
      Message.should_receive(:overview_of_created).with(options)
      subject.messages_received(options)
    end
  end

  describe "#users_texting" do
    it "should return the overview of all active users" do
      Message.should_receive(:overview_of_created).with(hash_including(options.merge(:by_user => true)))
      subject.users_texting(options)
    end
  end
end
