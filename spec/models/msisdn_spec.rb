require 'rails_helper'

describe Msisdn do

  def at_time(hours, minutes, &block)
    Timecop.freeze(Time.new(2015, 10, 22, hours, minutes)) do
      yield
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:replies) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:mobile_number) }
    it { is_expected.to validate_presence_of(:state) }
    it { is_expected.to validate_presence_of(:operator) }
    it { is_expected.to validate_presence_of(:country_code) }
    it { is_expected.to validate_presence_of(:number_of_checks) }
    it { is_expected.to validate_numericality_of(:number_of_checks).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe "callbacks" do
    describe "before_validation(:on => :create)" do
      subject { build(:msisdn) }

      before do
        subject.valid?
      end

      it "should set the operator and country_code" do
        expect(subject.operator).to be_present
        expect(subject.country_code).to be_present
      end
    end
  end

  describe "#discover!" do
    subject { create(:msisdn) }

    def setup_scenario
    end

    def assert_broadcast!
      subject.reload
      expect(subject.replies).not_to be_empty
      expect(subject.number_of_checks).to eq(1)
      expect(subject.last_checked_at).to be_present
    end

    def assert_no_broadcast!
      expect(subject.last_checked_at).to eq(nil)
    end

    before do
      setup_scenario
      subject.discover!
    end

    context "given no user exists with this msisdn" do
      it { assert_broadcast! }
    end

    context "given a user already exists with this msisdn" do
      context "and the user is offline" do
        def setup_scenario
          create(:user, :offline, :mobile_number => subject.mobile_number)
        end

        it { assert_broadcast! }
      end

      context "and the user is online" do
        def setup_scenario
          create(:user, :online, :mobile_number => subject.mobile_number)
        end

        it { assert_no_broadcast! }
      end
    end
  end

  describe ".queued" do
    let(:unchecked) { create(:msisdn, :unchecked) }
    let(:queued_for_checking) { create(:msisdn, :queued_for_checking) }
    let(:awaiting_result) { create(:msisdn, :awaiting_result) }
    let(:active) { create(:msisdn, :active) }
    let(:inactive) { create(:msisdn, :inactive) }

    before do
      [unchecked, queued_for_checking, awaiting_result, active, inactive]
    end

    it { expect(described_class.queued).to match_array([unchecked, queued_for_checking]) }
  end

  describe ".queue_full?" do
    before do
      create_list(:msisdn, number_in_queue)
    end

    context "queue max has been reached" do
      let(:number_in_queue) { 100 }
      it { expect(described_class).to be_queue_full }
    end

    context "queue max has not been reached" do
      let(:number_in_queue) { 99 }
      it { expect(described_class).not_to be_queue_full }
    end
  end

  describe ".queue_buffer" do
    before do
      create_list(:msisdn, number_in_queue)
    end

    context "queue is overfull" do
      let(:number_in_queue) { Msisdn::DEFAULT_BROADCAST_MAX_QUEUED + 10 }
      it { expect(described_class.queue_buffer).to eq(0) }
    end

    context "queue is empty" do
      let(:number_in_queue) { 0 }
      it { expect(described_class.queue_buffer).to eq(Msisdn::DEFAULT_BROADCAST_MAX_QUEUED) }
    end
  end

  describe ".out_of_broadcast_hours?" do
    context "too early" do
      it { at_time(7, 59) { expect(described_class).to be_out_of_broadcast_hours } }
    end

    context "too late" do
      it { at_time(20, 00) { expect(described_class).to be_out_of_broadcast_hours } }
    end

    context "in the morning" do
      it { at_time(8, 00) { expect(described_class).not_to be_out_of_broadcast_hours } }
    end

    context "in the evening" do
      it { at_time(19, 59) { expect(described_class).not_to be_out_of_broadcast_hours } }
    end
  end

  describe ".discover!" do
    def setup_scenario
    end

    before do
      setup_scenario
      at_time(Msisdn::DEFAULT_BROADCAST_HOURS_MIN, 0) { described_class.discover! }
    end

    context "given the queue has reached is maxiumum" do
      def setup_scenario
        create_list(:msisdn, Msisdn::DEFAULT_BROADCAST_MAX_QUEUED, :queued_for_checking)
      end

      it "should not queue any more jobs" do
        # expect no jobs here
      end
    end

    context "given there are no discoveries for this operator" do
      it "should queue some discoveries" do

      end
    end

    context "it should queue some MSISDN for discovery" do

    end

    context "given some msisdns have already been created" do
      let(:msisdn) { create(:msisdn) }
      let(:unregistered_msisdn) { create(:msisdn, :from_unregistered_operator) }

      def setup_scenario
        create(:msisdn)
      end

      it {}

    end
  end
end
