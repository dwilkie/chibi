require 'spec_helper'

describe Overview do
  let(:options) { { :some => :option } }

  def stub_overview(resource, value = [])
    resource.stub(:overview_of_created).and_return(value)
  end

  describe "#new_users" do
    before do
      stub_overview(User)
    end

    it "should return the overview of all new users" do
      User.should_receive(:overview_of_created).with(options).exactly(1).times
      subject.new_users(options)
      subject.new_users(options)
    end
  end

  describe "#messages_received" do
    before do
      stub_overview(Message)
    end

    it "should return the overview of all messages received" do
      Message.should_receive(:overview_of_created).with(options).exactly(1).times
      subject.messages_received(options)
      subject.messages_received(options)
    end
  end

  describe "#users_texting" do
    before do
      stub_overview(Message)
    end

    it "should return the overview of all active users" do
      Message.should_receive(:overview_of_created).with(hash_including(options.merge(:by_user => true))).exactly(1).times
      subject.users_texting(options)
      subject.users_texting(options)
    end
  end

  describe "#return_users" do
    before do
      stub_overview(User, [[1360886400000, 3], [1361232000000, 1]])
      stub_overview(Message, [[1360886400000, 6], [1361232000000, 3]])
    end

    it "should return an overview of the active users who are not new" do
      subject.return_users(options).should == [[1360886400000, 3], [1361232000000, 2]]
    end
  end

  describe "#profit" do
    before do
      stub_overview(Message, [[1360886400000, 100], [1361232000000, 50]])
    end

    it "should an overview of the profit" do
      subject.profit(options).should == [[1360886400000, 1.5], [1361232000000, 0.75]]
    end
  end
end
