require_relative 'phone_call_helpers'

module CommunicableExampleHelpers
  private

  def asserted_communicable_resources
    [:messages, :replies, :phone_calls]
  end
end

USER_TYPES_IN_CHAT = [:user, :friend, :inactive_user]

shared_examples_for "communicable" do
  let(:user_with_invalid_mobile_number) { build(:user, :with_invalid_mobile_number) }

  it "should not be valid without a user" do
    communicable_resource.user = nil
    communicable_resource.should_not be_valid
  end

  it "should not be valid with an invalid user" do
    communicable_resource.user = user_with_invalid_mobile_number
    communicable_resource.should_not be_valid
  end

  describe "callbacks" do
    context "when saving" do
      it "should record the user's last_contacted_at" do
        user_timestamp = communicable_resource.user.updated_at
        communicable_resource.save
        communicable_resource.user.updated_at.should > user_timestamp
        communicable_resource.user.last_contacted_at.should > user_timestamp
      end
    end
  end
end

shared_examples_for "communicable from user" do |options|
  options ||= {}

  let(:user) { build(:user) }

  it "should not be valid without a 'from'" do
    communicable_resource.from = ""
    communicable_resource.should_not be_valid
  end

  describe "#from=(value)" do
    include PhoneCallHelpers::TwilioHelpers

    it "should sanitize the number and remove multiple leading ones" do
      communicable_resource.from = "+1111-737-874-2833"
      communicable_resource.from.should == "17378742833"
      communicable_resource.from = nil
      communicable_resource.from.should be_nil

      # double leading 1 (Cambodia)
      communicable_resource.from = "+1185512808814"
      communicable_resource.from.should == "85512808814"

      # single leading 1 (Cambodia)
      communicable_resource.from = "+185512808814"
      communicable_resource.from.should == "85512808814"

      # no leading 1 (Cambodia)
      communicable_resource.from = "+85512808814"
      communicable_resource.from.should == "85512808814"

      # single leading 1 (Thai)
      communicable_resource.from = "+166814417695"
      communicable_resource.from.should == "66814417695"

      # no leading 1 (Thai)
      communicable_resource.from = "+66814417695"
      communicable_resource.from.should == "66814417695"

      # single leading 1 (Australia)
      communicable_resource.from = "+161412345678"
      communicable_resource.from.should == "61412345678"

      # no leading 1 (Australia)
      communicable_resource.from = "+61412345678"
      communicable_resource.from.should == "61412345678"

      # test normal US number
      communicable_resource.from = "+17378742833"
      communicable_resource.from.should == "17378742833"

      # test Twilio number
      communicable_resource.from = "+1-234-567-8912"
      twilio_numbers.each do |number|
        communicable_resource.from = number
        communicable_resource.from.should == "12345678912"
      end

      # test invalid number
      communicable_resource.from = "+1-234-567-8912"
      communicable_resource.from = build(:user, :with_invalid_mobile_number).mobile_number
      communicable_resource.from.should == "12345678912"

      # test invalid E.164 number
      communicable_resource.from = "855010123456"
      communicable_resource.from.should == "85510123456"

      # test invalid long E.164 number
      communicable_resource.from = "8550961234567"
      communicable_resource.from.should == "855961234567"

      # test incorrect country code
      communicable_resource.from = "198786779"
      communicable_resource.from.should == "85598786779"

      # test incorrect country code with leading '0'
      communicable_resource.from = "1098786779"
      communicable_resource.from.should == "85598786779"
    end
  end

  describe "callbacks" do
    context "after_create" do
      if options[:passive]
        it "should not record the users's last_interacted_at" do
          communicable_resource.user.last_interacted_at.should be_nil
        end
      else
        it "should record the users's last_interacted_at" do
          communicable_resource.user.last_interacted_at.should be_present
        end
      end
    end

    context "before validation(:on => :create)" do
      it "should try to find or initialize the user with the mobile number" do
        User.should_receive(:find_or_initialize_by).with(:mobile_number => user.mobile_number)
        subject.class.new(:from => user.mobile_number).valid?
      end

      context "if a user with that number exists" do
        before do
          user.save
        end

        it "should find the user and assign it to itself" do
          subject.user.should be_nil
          subject.from = user.mobile_number
          subject.valid?
          subject.user.should == user
        end
      end

      context "if a user with that number does not exist" do
        it "should initialize a new user and assign it to itself" do
          subject.user.should be_nil
          subject.from = user.mobile_number
          subject.valid?
          subject.user.mobile_number.should == user.mobile_number
        end
      end
    end
  end
end

shared_examples_for "chatable" do
  let(:chat) { create(:chat, :active, :user => user) }
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

shared_examples_for "filtering with communicable resources" do
  include CommunicableExampleHelpers

  before do
    resources
  end

  describe ".filter_by" do
    it "should order by latest updated at" do
      subject.class.filter_by.should == resources.reverse
    end

    it "should include the communicable resources associations" do
      subject.class.filter_by.includes_values.should include(*asserted_communicable_resources)
    end
  end

  describe ".filter_by_count" do
    it "should return the total number of resources" do
      subject.class.filter_by_count.should == resources.count
    end
  end

  describe ".filter_params" do
    it "should return the total number of resources" do
      subject.class.filter_params.should == subject.class.all
    end
  end

  describe ".communicable_resources" do
    it "should return the configured communicable resources" do
      subject.class.communicable_resources.should =~ asserted_communicable_resources
    end
  end

  describe ".find_with_communicable_resources" do
    it "should behave like .find but the result should include the communicable resources" do
      expect {
        subject.class.find_with_communicable_resources(0)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
