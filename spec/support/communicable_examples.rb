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
    expect(communicable_resource).not_to be_valid
  end

  it "should not be valid with an invalid user" do
    communicable_resource.user = user_with_invalid_mobile_number
    expect(communicable_resource).not_to be_valid
  end

  describe "callbacks" do
    context "when saving" do
      it "should record the user's last_contacted_at" do
        user_timestamp = communicable_resource.user.updated_at
        communicable_resource.touch
        expect(communicable_resource.user.updated_at).to be > user_timestamp
        expect(communicable_resource.user.last_contacted_at).to be > user_timestamp
      end
    end
  end
end

shared_examples_for "communicable from user" do |options|
  options ||= {}

  let(:user) { build(:user) }

  it "should not be valid without a 'from'" do
    communicable_resource.from = ""
    expect(communicable_resource).not_to be_valid
  end

  describe "#from=(value)" do
    include PhoneCallHelpers::TwilioHelpers
    include MobilePhoneHelpers

    it "should sanitize the number" do
      communicable_resource.from = "+1111-737-874-2833"
      expect(communicable_resource.from).to eq("17378742833")
      communicable_resource.from = nil
      expect(communicable_resource.from).to be_nil

      # double leading 1 (Cambodia)
      communicable_resource.from = "+1185512808814"
      expect(communicable_resource.from).to eq("85512808814")

      # single leading 1 (Cambodia)
      communicable_resource.from = "+185512808814"
      expect(communicable_resource.from).to eq("85512808814")

      # no leading 1 (Cambodia)
      communicable_resource.from = "+85512808814"
      expect(communicable_resource.from).to eq("85512808814")

      # single leading 1 (Thai)
      communicable_resource.from = "+166814417695"
      expect(communicable_resource.from).to eq("66814417695")

      # no leading 1 (Thai)
      communicable_resource.from = "+66814417695"
      expect(communicable_resource.from).to eq("66814417695")

      # single leading 1 (Australia)
      communicable_resource.from = "+161412345678"
      expect(communicable_resource.from).to eq("61412345678")

      # no leading 1 (Australia)
      communicable_resource.from = "+61412345678"
      expect(communicable_resource.from).to eq("61412345678")

      # test normal US number
      communicable_resource.from = "+17378742833"
      expect(communicable_resource.from).to eq("17378742833")

      # test Twilio number
      communicable_resource.from = "+1-234-567-8912"
      twilio_numbers.each do |number|
        communicable_resource.from = number
        expect(communicable_resource.from).to eq("12345678912")
      end

      # test all numbers in Torasup Gem
      with_operators(:only_registered => false) do |number_parts, assertions|
        country_code = number_parts.shift
        local_number = number_parts.join
        full_number = country_code + local_number
        communicable_resource.from = nil
        communicable_resource.from = "+#{local_number}"
        expect(communicable_resource.from).to eq("855#{local_number}")
        communicable_resource.from = "+#{full_number}"
        expect(communicable_resource.from).to eq(full_number)
      end

      # test invalid number
      communicable_resource.from = "+1-234-567-8912"
      communicable_resource.from = build(:user, :with_invalid_mobile_number).mobile_number
      expect(communicable_resource.from).to eq("12345678912")

      # test invalid E.164 number
      communicable_resource.from = "855010234567"
      expect(communicable_resource.from).to eq("85510234567")

      # test invalid long E.164 number
      communicable_resource.from = "8550962345678"
      expect(communicable_resource.from).to eq("855962345678")

      # test incorrect country code
      communicable_resource.from = "198786779"
      expect(communicable_resource.from).to eq("85598786779")

      # test another incorrect country code
      communicable_resource.from = "110234567"
      expect(communicable_resource.from).to eq("85510234567")

      # test incorrect country code with leading '0'
      communicable_resource.from = "1098786779"
      expect(communicable_resource.from).to eq("85598786779")

      # test no country code
      communicable_resource.from = "+0977121234"
      expect(communicable_resource.from).to eq("855977121234")

      # test no country code starting with 01
      communicable_resource.from = "+010830237"
      expect(communicable_resource.from).to eq("85510830237")

      # test no country code starting with 08
      communicable_resource.from = "+089830237"
      expect(communicable_resource.from).to eq("85589830237")

      # test added 0's
      communicable_resource.from = "+100855388880112"
      expect(communicable_resource.from).to eq("855388880112")
    end
  end

  describe "callbacks" do
    context "after_create" do
      if options[:passive]
        it "should not record the users's last_interacted_at" do
          expect(communicable_resource.user.last_interacted_at).to be_nil
        end
      else
        it "should record the users's last_interacted_at" do
          expect(communicable_resource.user.last_interacted_at).to be_present
        end
      end
    end

    context "before validation(:on => :create)" do
      it "should try to find or initialize the user with the mobile number" do
        expect(User).to receive(:find_or_initialize_by).with(:mobile_number => user.mobile_number)
        subject.class.new(:from => user.mobile_number).valid?
      end

      context "if a user with that number exists" do
        before do
          user.save
        end

        it "should find the user and assign it to itself" do
          expect(subject.user).to be_nil
          subject.from = user.mobile_number
          subject.valid?
          expect(subject.user).to eq(user)
        end
      end

      context "if a user with that number does not exist" do
        it "should initialize a new user and assign it to itself" do
          expect(subject.user).to be_nil
          subject.from = user.mobile_number
          subject.valid?
          expect(subject.user.mobile_number).to eq(user.mobile_number)
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

      expect(chat.reload.updated_at).to be > original_chat_timestamp
    end
  end

  describe ".filter_by" do
    let(:another_chatable_resource) { create(chatable_resource.class.to_s.underscore.to_sym, :chat => chat) }

    before do
      another_chatable_resource
    end

    context "passing no params" do
      it "should return all chatable resources ordered by latest created at date" do
        expect(subject.class.filter_by).to eq([another_chatable_resource, chatable_resource])
      end
    end

    context ":user_id => 2" do
      it "should return all chatable resources with the given user id" do
        expect(subject.class.filter_by(:user_id => chatable_resource.user.id)).to eq([chatable_resource])
      end
    end

    context ":chat_id => 2" do
      it "should return all messages with the given chat id" do
        expect(subject.class.filter_by(:chat_id => chat.id)).to eq([another_chatable_resource])
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
      expect(subject.class.filter_by).to eq(resources.reverse)
    end

    it "should include the communicable resources associations" do
      expect(subject.class.filter_by.includes_values).to include(*asserted_communicable_resources)
    end
  end

  describe ".filter_by_count" do
    it "should return the total number of resources" do
      expect(subject.class.filter_by_count).to eq(resources.count)
    end
  end

  describe ".filter_params" do
    it "should return the total number of resources" do
      expect(subject.class.filter_params).to eq(subject.class.all)
    end
  end

  describe ".communicable_resources" do
    it "should return the configured communicable resources" do
      expect(subject.class.communicable_resources).to match_array(asserted_communicable_resources)
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
