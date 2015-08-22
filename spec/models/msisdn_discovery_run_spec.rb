require 'rails_helper'

describe MsisdnDiscoveryRun do
  include TimecopHelpers

  describe "associations" do
    it { is_expected.to have_many(:msisdn_discoveries) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:operator) }
    it { is_expected.to validate_presence_of(:country_code) }
    it { is_expected.to validate_presence_of(:prefix) }
    it { is_expected.to validate_presence_of(:subscriber_number_min) }
    it { is_expected.to validate_presence_of(:subscriber_number_max) }
    it { is_expected.to validate_numericality_of(:subscriber_number_min).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:subscriber_number_max).only_integer.is_greater_than_or_equal_to(0) }
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

  describe ".queue_full?" do
    before do
      create_list(:msisdn_discovery, number_in_queue)
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
    let(:queue_buffer) { described_class.queue_buffer }

    before do
      create_list(:msisdn_discovery, number_in_queue)
    end

    context "queue is overfull" do
      let(:number_in_queue) { described_class::DEFAULT_BROADCAST_MAX_QUEUED + 10 }
      it { expect(queue_buffer).to eq(0) }
    end

    context "queue is empty" do
      let(:number_in_queue) { 0 }
      it { expect(queue_buffer).to be <= described_class::DEFAULT_BROADCAST_MAX_QUEUED }
      it { expect(queue_buffer).to be > 0 }
    end
  end

  describe ".active" do
    let(:active_msisdn_discovery_run) { create(:msisdn_discovery_run) }

    before do
      active_msisdn_discovery_run
      create(:msisdn_discovery_run, :inactive)
    end

    it { expect(described_class.active).to match_array([active_msisdn_discovery_run]) }
  end

  describe ".cleanup!" do
    let(:msisdn_discovery_run) { create(:msisdn_discovery_run) }
    let(:inactive_msisdn_discovery_run) { create(:msisdn_discovery_run, :inactive) }
    let(:inactive_msisdn_discovery_run_with_msisdn_discoveries) { create(:msisdn_discovery, :from_inactive_msisdn_discovery_run).msisdn_discovery_run }

    def setup_scenario
      msisdn_discovery_run
      inactive_msisdn_discovery_run
      inactive_msisdn_discovery_run_with_msisdn_discoveries
    end

    before do
      setup_scenario
      described_class.cleanup!
    end

    it { expect(MsisdnDiscoveryRun.all).to match_array([msisdn_discovery_run, inactive_msisdn_discovery_run_with_msisdn_discoveries]) }
  end

  describe ".discover!" do
    include ActiveJobHelpers

    def setup_scenario
    end

    def assert_no_discovery!
      expect(enqueued_jobs).to be_empty
    end

    let(:current_time) { described_class::DEFAULT_BROADCAST_HOURS_MIN }

    before do
      setup_scenario
      at_time(*[current_time].flatten) { trigger_job(job_options) { described_class.discover! } }
    end

    context "given discovery will not be enqueued" do
      let(:job_options) { { :queue_only => true } }

      context "because the queue has reached it's maximum" do
        def setup_scenario
          create_list(
            :msisdn_discovery,
            described_class::DEFAULT_BROADCAST_MAX_QUEUED,
            :queued_for_discovery
          )
        end

        it { assert_no_discovery! }
      end

      context "because it's out of broadcast hours" do
        let(:current_time) { described_class::DEFAULT_BROADCAST_HOURS_MAX + 1 }
        it { assert_no_discovery! }
      end
    end

    context "given discovery will be enqueued" do
      let(:job_options) { {} }

      def assert_discovery!
        expect(MsisdnDiscovery.count).to eq(described_class::DEFAULT_BROADCAST_MAX_QUEUED)
      end

      context "when the queue is empty" do
        it { assert_discovery! }
      end

      context "a discovery run already exists" do
        def setup_scenario
          super
          expect(msisdn_discovery_run).to be_active
        end

        context "that's finished" do
          let(:msisdn_discovery_run) { create(:msisdn_discovery_run, :finished) }

          def assert_discovery!
            msisdn_discovery_run.reload
            expect(msisdn_discovery_run.msisdn_discoveries.count).to eq(1)
            expect(MsisdnDiscovery.count).to be > 1
            expect(msisdn_discovery_run).not_to be_active
          end

          it { assert_discovery! }
        end

        context "that's nearly finished" do
          let(:msisdn_discovery_run) { create(:msisdn_discovery_run, :nearly_finished) }

          def assert_discovery!
            msisdn_discovery_run.reload
            expect(MsisdnDiscovery.count).to be > 1
            expect(msisdn_discovery_run).to be_finished
            expect(msisdn_discovery_run).to be_active
          end

          it { assert_discovery! }
        end
      end
    end
  end

  describe "#random_batch" do
    subject { create(:msisdn_discovery_run) }
    it { expect(subject.random_batch(10)).not_to eq(subject.random_batch(10)) }
  end

  describe "#discover!(subscriber_number)" do
    subject { create(:msisdn_discovery_run) }

    let(:subscriber_number) { subject.subscriber_number_min }

    def setup_scenario
    end

    before do
      setup_scenario
      subject.discover!(subscriber_number)
    end

    it { expect(subject.reload.msisdn_discoveries.last!.subscriber_number).to eq(subscriber_number) }

    context "given a discovery already exists for this subscriber number" do
      let(:msisdn_discovery) { create(:msisdn_discovery, :msisdn_discovery_run => subject, :subscriber_number => subscriber_number) }

      def setup_scenario
        msisdn_discovery
      end

      it { expect(subject.reload.msisdn_discoveries.count).to eq(1) }
    end
  end

  describe "#finished?" do
    context "all possibilities" do
      context "have been discovered" do
        subject { create(:msisdn_discovery_run, :finished) }
        it { is_expected.to be_finished }
      end

      context "have not been discovered" do
        subject { create(:msisdn_discovery_run) }
        it { is_expected.not_to be_finished }
      end
    end
  end
end
