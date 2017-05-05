require_relative 'phone_call_helpers'
require_relative 'twilio_helpers'

module CommunicableExampleHelpers
  private

  def asserted_communicable_resources
    [:messages, :replies, :phone_calls]
  end
end

USER_TYPES_IN_CHAT = [:user, :friend, :active_user]

shared_examples_for "communicable from user" do |options|
  options ||= {}

  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    let(:user_with_invalid_mobile_number) { build(:user, :with_invalid_mobile_number) }
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:from) }

    it "should not be valid with an invalid user" do
      subject.user = user_with_invalid_mobile_number
      expect(subject).not_to be_valid
      expect(subject.errors[:user]).not_to be_empty
    end
  end

  describe "#from=(value)" do
    include MobilePhoneHelpers
    include TwilioHelpers

    it "should sanitize the number" do
      subject.from = "+1111-737-874-2833"
      expect(subject.from).to eq("17378742833")
      subject.from = nil
      expect(subject.from).to be_nil

      # double leading 1 (Cambodia)
      subject.from = "+1185512808814"
      expect(subject.from).to eq("85512808814")

      # single leading 1 (Cambodia)
      subject.from = "+185512808814"
      expect(subject.from).to eq("85512808814")

      # no leading 1 (Cambodia)
      subject.from = "+85512808814"
      expect(subject.from).to eq("85512808814")

      # single leading 1 (Thai)
      subject.from = "+166814417695"
      expect(subject.from).to eq("66814417695")

      # no leading 1 (Thai)
      subject.from = "+66814417695"
      expect(subject.from).to eq("66814417695")

      # single leading 1 (Australia)
      subject.from = "+161412345678"
      expect(subject.from).to eq("61412345678")

      # no leading 1 (Australia)
      subject.from = "+61412345678"
      expect(subject.from).to eq("61412345678")

      # test normal US number
      subject.from = "+17378742833"
      expect(subject.from).to eq("17378742833")

      # test Twilio number
      subject.from = "+1-234-567-8912"
      twilio_numbers.each do |number|
        subject.from = number
        expect(subject.from).to eq("12345678912")
      end

      # test all numbers in Torasup Gem
      with_operators(:only_registered => false) do |number_parts, assertions|
        country_code = number_parts.shift
        local_number = number_parts.join
        full_number = country_code + local_number
        subject.from = nil
        subject.from = "+#{local_number}"
        expect(subject.from).to eq("855#{local_number}")
        subject.from = "+#{full_number}"
        expect(subject.from).to eq(full_number)
      end

      # test invalid number
      subject.from = "+1-234-567-8912"
      subject.from = build(:user, :with_invalid_mobile_number).mobile_number
      expect(subject.from).to eq("12345678912")

      # test invalid E.164 number
      subject.from = "855010234567"
      expect(subject.from).to eq("85510234567")

      # test invalid long E.164 number
      subject.from = "8550962345678"
      expect(subject.from).to eq("855962345678")

      # test incorrect country code
      subject.from = "198786779"
      expect(subject.from).to eq("85598786779")

      # test another incorrect country code
      subject.from = "110234567"
      expect(subject.from).to eq("85510234567")

      # test incorrect country code with leading '0'
      subject.from = "1098786779"
      expect(subject.from).to eq("85598786779")

      # test no country code
      subject.from = "+0977121234"
      expect(subject.from).to eq("855977121234")

      # test no country code starting with 01
      subject.from = "+010830237"
      expect(subject.from).to eq("85510830237")

      # test no country code starting with 08
      subject.from = "+089830237"
      expect(subject.from).to eq("85589830237")

      # test added 0's
      subject.from = "+100855388880112"
      expect(subject.from).to eq("855388880112")
    end
  end

  describe "callbacks" do
    context "after_commit(:on => :create)" do
      let(:interactor) { subject.user }

      if options[:passive]
        it { expect(interactor.last_interacted_at).to eq(nil) }
      else
        it { expect(interactor.last_interacted_at).to be_present }
      end
    end

    context "before validation(:on => :create)" do
      subject { described_class.new }

      before do
        subject.from = from
        subject.valid?
      end

      context "if a user with the from from number exists" do
        let(:user) { create(:user) }
        let(:from) { user.mobile_number }

        it { expect(subject.user).to eq(user) }
      end

      context "if a user with the from number does not exist" do
        let(:from) { generate(:mobile_number) }

        it { expect(subject.user.mobile_number).to eq(from) }
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
end
