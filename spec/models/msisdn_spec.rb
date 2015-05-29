require 'rails_helper'

describe Msisdn do
  describe "validations" do
    it { is_expected.to validate_presence_of(:mobile_number) }
    it { is_expected.to validate_presence_of(:state) }
    it { is_expected.to validate_presence_of(:operator) }
    it { is_expected.to validate_presence_of(:country_code) }
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

  describe ".foo", :focus do
    def setup_scenario
    end

    before do
      setup_scenario
      described_class.foo
    end

    context "given the queue has reached is maxiumum" do
      def setup_scenario
        create_list(:msisdn, Msisdn::DEFAULT_BROADCAST_MAX_QUEUED, :queued_for_checking)
      end

      it "should not queue any more jobs" do
        # expect no jobs here
      end
    end

    context "given some msisdns have already been created" do
      let(:msisdn) { create(:msisdn) }
      let(:unregistered_msisdn) { create(:msisdn, :from_unregistered_operator) }

      before do
        [msisdn, unregistered_msisdn]
      end

      it { described_class.foo }
    end
  end
end
