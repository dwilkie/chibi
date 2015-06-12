require 'rails_helper'

describe MsisdnDiscovery do
  describe "associations" do
    it { is_expected.to belong_to(:msisdn_discovery_run) }
    it { is_expected.to belong_to(:msisdn) }
  end

  describe "validations" do
    let(:msisdn_discovery_run) {
      create(
        :msisdn_discovery_run,
        :subscriber_number_min => 203000,
        :subscriber_number_max => 999999
      )
    }

    subject { create(:msisdn_discovery, :msisdn_discovery_run => msisdn_discovery_run) }

    it { is_expected.to validate_presence_of(:state) }

    it do
      is_expected.to validate_numericality_of(
        :subscriber_number
      ).only_integer.is_greater_than_or_equal_to(203000)
    end

    it do
      is_expected.to validate_numericality_of(
        :subscriber_number
      ).only_integer.is_less_than_or_equal_to(999999)
    end

    it { is_expected.to validate_presence_of(:msisdn_discovery_run) }
    it { is_expected.to validate_presence_of(:msisdn) }

    describe "#msisdn_id" do
      let(:existing_msisdn_discovery) { create(:msisdn_discovery) }
      subject {
        build(
          :msisdn_discovery,
          :subscriber_number => existing_msisdn_discovery.subscriber_number,
          :msisdn_discovery_run => existing_msisdn_discovery.msisdn_discovery_run
        )
      }

      it { is_expected.not_to be_valid; expect(subject.errors[:msisdn_id]).not_to be_empty }
    end
  end

  describe "callbacks" do
    describe "before_validation(:on => :create)" do
      subject { build(:msisdn_discovery) }

      before do
        subject.valid?
      end

      it "should set the msisdn" do
        expect(subject.msisdn).to be_present
      end
    end
  end

  describe ".queued" do
    let(:not_started) { create(:msisdn_discovery, :not_started) }
    let(:skipped) { create(:msisdn_discovery, :skipped) }
    let(:queued_for_discovery) { create(:msisdn_discovery, :queued_for_discovery) }
    let(:awaiting_result) { create(:msisdn_discovery, :awaiting_result) }
    let(:active) { create(:msisdn_discovery, :active) }
    let(:inactive) { create(:msisdn_discovery, :inactive) }

    before do
      [not_started, queued_for_discovery, awaiting_result, active, inactive, skipped]
    end

    it { expect(described_class.queued).to match_array([not_started, queued_for_discovery]) }
  end

  describe ".highest_discovered_subscriber_number" do
    let(:highest_subscriber_number) { msisdn_discovery_run.subscriber_number_max }
    let(:msisdn_discovery_run) { create(:msisdn_discovery_run) }

    before do
      create(:msisdn_discovery, :subscriber_number => highest_subscriber_number)
      create(:msisdn_discovery, :subscriber_number => msisdn_discovery_run.subscriber_number_min)
    end

    it { expect(described_class.highest_discovered_subscriber_number).to eq(highest_subscriber_number) }
  end

  describe ".cleanup_queued!" do
    def create_msisdn_discovery(*args)
      options = args.extract_options!
      outdated_state = options.delete(:outdated_state)
      msisdn_discovery = create(:msisdn_discovery, *args, options)
      msisdn_discovery.update_column(:state, outdated_state) if outdated_state
      msisdn_discovery
    end

    let(:msisdn_discovery_queued_too_long_with_missing_broadcast) { create_msisdn_discovery(:queued_too_long) }
    let(:msisdn_discovery_with_missing_broadcast) { create_msisdn_discovery }
    let(:msisdn_discovery_queued_too_long_with_outdated_state) { create_msisdn_discovery(:queued_too_long, :with_outdated_state, :outdated_state => :queued_for_discovery) }
    let(:msisdn_discovery_with_outdated_state) { create_msisdn_discovery(:with_outdated_state, :outdated_state => :queued_for_discovery) }

    before do
      msisdn_discovery_queued_too_long_with_missing_broadcast
      msisdn_discovery_with_missing_broadcast
      expect(msisdn_discovery_queued_too_long_with_outdated_state).not_to be_active
      expect(msisdn_discovery_queued_too_long_with_missing_broadcast.reply).to eq(nil)
      described_class.cleanup_queued!
    end

    it { expect(msisdn_discovery_queued_too_long_with_missing_broadcast.reload.reply).to be_present }
    it { expect(msisdn_discovery_with_missing_broadcast.reload.reply).to eq(nil) }
    it { expect(msisdn_discovery_queued_too_long_with_outdated_state.reload).to be_active }
    it { expect(msisdn_discovery_with_outdated_state.reload).not_to be_active }
  end

  describe "#broadcast!" do
    before do
      subject.broadcast!
      subject.reload
    end

    context "msisdn is not blacklisted" do
      subject { create(:msisdn_discovery) }
      it { expect(subject.reply).to be_persisted }
      it { is_expected.to be_queued_for_discovery }
    end

    context "msisdn is blacklisted" do
      subject { create(:msisdn_discovery, :blacklisted) }

      it { expect(subject.reply).to eq(nil) }
      it { is_expected.to be_skipped }
    end
  end

  describe "#notify" do
    let(:msisdn) { subject.msisdn }

    def setup_scenario
      reply
      subject.reload
    end

    before do
      setup_scenario
    end

    subject { create(:msisdn_discovery, state) }
    let(:reply) { create(:reply, reply_state, :msisdn_discovery => subject) }

    context "reply state is:" do
      context "pending_delivery" do
        let(:reply_state) { :pending_delivery }
        let(:state) { :not_started }
        it { is_expected.to be_not_started }
      end

      context "queued_for_smsc_delivery" do
        let(:reply_state) { :queued_for_smsc_delivery }
        let(:state) { :not_started }
        it { is_expected.to be_queued_for_discovery }

        context "this state is queued_for_discovery" do
          let(:state) { :queued_for_discovery }

          def setup_scenario
          end

          it { expect { reply }.not_to raise_error }
        end
      end

      context "confirmed" do
        let(:reply_state) { :confirmed }
        let(:state) { :awaiting_result }
        it { is_expected.to be_active }
        it { expect(msisdn).to be_active }
      end

      context "failed" do
        let(:reply_state) { :failed }
        let(:state) { :awaiting_result }
        it { is_expected.to be_inactive }
        it { expect(msisdn).not_to be_active }

        context "this state is queued_for_discovery" do
          let(:state) { :queued_for_discovery }
          it { is_expected.to be_inactive }
          it { expect(msisdn).not_to be_active }
        end
      end

      context "expired" do
        let(:reply_state) { :expired }
        let(:state) { :awaiting_result }
        it { is_expected.to be_inactive }
        it { expect(msisdn).not_to be_active }
      end
    end
  end
end
