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

  describe "#revenue" do
    before do
      stub_overview(Message, [[1360886400000, 16845], [1361232000000, 16567]])
    end

    it "should an overview of the revenue" do
      subject.revenue(options).should == [[1360886400000, 842.25], [1361232000000, 828.35]]
    end
  end

  describe "#inbound_cdrs" do
    before do
      stub_overview(InboundCdr, [])
    end

    it "should return an overview of the inbound cdrs" do
      InboundCdr.should_receive(:overview_of_created).with(options)
      subject.inbound_cdrs(options)
    end
  end

  describe "#phone_calls" do
    before do
      stub_overview(PhoneCall, [])
    end

    it "should return an overview of the phone calls" do
      PhoneCall.should_receive(:overview_of_created).with(options)
      subject.phone_calls(options)
    end
  end
end
