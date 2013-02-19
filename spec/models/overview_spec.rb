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
      User.should_receive(:overview_of_created).with(options).once
      User.should_receive(:overview_of_created).once
      subject.new_users(options)
      subject.new_users(options)
      subject.new_users
    end
  end

  describe "#messages_received" do
    before do
      stub_overview(Message)
    end

    it "should return the overview of all messages received" do
      Message.should_receive(:overview_of_created).with(options).once
      Message.should_receive(:overview_of_created).once
      subject.messages_received(options)
      subject.messages_received(options)
      subject.messages_received
    end
  end

  describe "#users_texting" do
    before do
      stub_overview(Message)
    end

    it "should return the overview of all active users" do
      Message.should_receive(:overview_of_created).with(hash_including(options.merge(:by_user => true))).once
      Message.should_receive(:overview_of_created).once
      subject.users_texting(options)
      subject.users_texting(options)
      subject.users_texting
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
      stub_overview(Message, [[1360886400000, 16845], [1361232000000, 16567]])
    end

    it "should an overview of the profit" do
      subject.profit(options).should == [[1360886400000, 252.68], [1361232000000, 248.51]]
    end
  end
end
