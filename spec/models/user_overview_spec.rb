require 'spec_helper'

describe UserOverview do

  let(:params) { { :page => "1" } }
  let(:subject) { UserOverview.new(params) }
  let(:users) { mock(ActiveRecord::Relation, :count => 5).as_null_object }

  def stub_filter_by
    User.stub(:filter_by).and_return(users)
  end

  def stub_filter_params
    User.stub(:filter_params).and_return(users)
  end

  describe "#total_available_users" do
    before do
      stub_filter_params
    end

    it "return the total number of available users" do
      User.should_receive(:filter_params).with(hash_including(:available => true))
      subject.total_available_users.should == 5
    end
  end

  describe "#total_available_males" do
    before do
      stub_filter_params
    end

    it "return the total number of available males" do
      User.should_receive(:filter_params).with(hash_including(:available => true, :gender => "m"))
      subject.total_available_males.should == 5
    end
  end

  describe "#total_available_females" do
    before do
      stub_filter_params
    end

    it "return the total number of available females" do
      User.should_receive(:filter_params).with(hash_including(:available => true, :gender => "f"))
      subject.total_available_females.should == 5
    end
  end

  describe "#paginated_users" do
    before do
      stub_filter_by
    end

    it "should return the paginated users" do
      users.should_receive(:page).with("1")
      subject.paginated_users
    end
  end

  describe "#total_users" do
    it "should return the total number of users filtered by params" do
      User.should_receive(:filter_by_count).with(params)
      subject.total_users
    end
  end
end
