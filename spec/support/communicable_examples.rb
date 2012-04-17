CHATABLE_RESOURCES = [:messages, :replies, :phone_calls]
USER_TYPES_IN_CHAT = [:user, :friend, :inactive_user]

shared_examples_for "communicable" do
  let(:user_with_invalid_mobile_number) { build(:user_with_invalid_mobile_number) }
  let(:user) { build(:user) }

  it "should not be valid without a user" do
    communicable_resource.user = nil
    communicable_resource.should_not be_valid
  end

  it "should not be valid with an invalid user" do
    communicable_resource.user = user_with_invalid_mobile_number
    communicable_resource.should_not be_valid
  end

  it "should not be valid without a 'from'" do
    communicable_resource.from = ""
    communicable_resource.should_not be_valid
  end

  describe "#from=" do
    it "should sanitize the number" do
      communicable_resource.from = "+1-3323-23345"
      communicable_resource.from.should == "1332323345"

      subject.from = nil
      subject.from.should be_nil
    end
  end

  describe "callbacks" do
    context "when inititalizing with an origin" do

      before do
        subject # this is needed so we can call subject.class without re-calling after_initialize
      end

      it "should try to find or initialize the user with the mobile number" do
        User.should_receive(:find_or_initialize_by_mobile_number).with(user.mobile_number)
        subject.class.new(:from => user.mobile_number)
      end

      context "if a user with that number exists" do
        before do
          user.save
        end

        it "should find the user and assign it to itself" do
          subject.class.new(:from => user.mobile_number).user.should == user
        end
      end

      context "if a user with that number does not exist" do
        it "should initialize a new user and assign it to itself" do
          communicable = subject.class.new(:from => user.mobile_number)
          assigned_user = communicable.user
          assigned_user.should be_present
          assigned_user.mobile_number.should == user.mobile_number
        end
      end

      context "if it already has an associated user" do
        it "should not load the associated user to check if it exists" do
          # Otherwise it will load every user when doing an index
          subject.class.any_instance.stub(:user).and_return(mock_model(User))
          subject.class.any_instance.stub(:user_id).and_return(nil)
          User.stub(:find_or_initialize_by_mobile_number)
          User.should_receive(:find_or_initialize_by_mobile_number)
          subject.class.new
        end

        it "should not try to find the associated user" do
          communicable_resource.save
          User.should_not_receive(:find_or_initialize_by_mobile_number)
          subject.class.find(communicable_resource.id)
        end
      end
    end
  end
end

shared_examples_for "chatable" do

  let(:chat) { create(:active_chat, :user => user) }
  let(:user) { build(:user) }

  context "when saving with an associated chat" do
    before do
      chat
      chatable_resource.save
    end

    it "should touch the chat" do
      original_chat_timestamp = chat.updated_at

      chatable_resource.chat = chat
      chatable_resource.save

      chat.reload.updated_at.should > original_chat_timestamp
    end
  end

  describe ".filter_by" do
    let(:another_chatable_resource) { create(chatable_resource.class.to_s.underscore.to_sym, :chat => chat) }

    before do
      another_chatable_resource
    end

    context "passing no params" do
      it "should return all chatable resources ordered by latest created at date" do
        subject.class.filter_by.should == [another_chatable_resource, chatable_resource]
      end
    end

    context ":user_id => 2" do
      it "should return all chatable resources with the given user id" do
        subject.class.filter_by(:user_id => chatable_resource.user.id).should == [chatable_resource]
      end
    end

    context ":chat_id => 2" do
      it "should return all messages with the given chat id" do
        subject.class.filter_by(:chat_id => chat.id).should == [another_chatable_resource]
      end
    end
  end
end

shared_examples_for "filtering with chatable resources" do

  def assert_respond_to_chatable_resources_counts(result)
    result.messages_count.should == "0"
    result.replies_count.should == "0"
    result.phone_calls_count.should == "0"
  end

  before do
    resources
  end

  describe ".filter_by" do
    it "should order by latest created at" do
      subject.class.filter_by.should == resources.reverse
    end

    it "should include a count of the chatable resources associations" do
      relation = subject.class.filter_by
      relation.select_values.first.split(/\,\s+/)[1..-1].should == [
        "COUNT(DISTINCT(messages.id)) AS messages_count",
        "COUNT(DISTINCT(replies.id)) AS replies_count",
        "COUNT(DISTINCT(phone_calls.id)) AS phone_calls_count"
      ]

      expected_table_name = subject.class.table_name
      expected_join_column = "#{expected_table_name.singularize}_id"

      relation.joins_values.each do |left_outer_join|
        join_extraction = left_outer_join.match(/(\w+)\s*\=\s*(\w+)/)
        join_extraction[1].should == expected_join_column
        table_name = expected_table_name
      end
    end

    it "should include counts for the chatable resources" do
      assert_respond_to_chatable_resources_counts(subject.class.filter_by.first)
    end
  end

  describe ".filter_by_count" do
    it "should return the total number of resources" do
      subject.class.filter_by_count.should == resources.count
    end
  end

  describe ".find_with_chatable_resources_counts" do
    it "should behave like .find but the result should respond to counts for chatable resources" do
      assert_respond_to_chatable_resources_counts(
        subject.class.find_with_chatable_resources_counts(resources.first.id)
      )

      expect {
        subject.class.find_with_chatable_resources_counts(0)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
