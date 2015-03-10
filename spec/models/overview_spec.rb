require 'rails_helper'

describe Overview do
  let(:options) { { :operator => "operator", :country_code => "country_code" } }

  def asserted_options(overridden = {})
    options.merge(:least_recent => 3.months).merge(overridden)
  end

  subject { Overview.new(options) }

  def stub_overview(resource, value = [])
    allow(resource).to receive(asserted_message_expectation).and_return(value)
  end

  def asserted_message_expectation
    :overview_of_created
  end

  def asserted_message_args(overridden_options = {})
    [asserted_options.merge(overridden_options)]
  end

  describe "#timeframe=(value)" do
    it "should update the options" do
      subject.timeframe = :day
      expect(subject.options[:timeframe]).to eq(:day)
      expect(subject.timeframe).to eq(:day)
    end
  end

  shared_examples_for "an overview method" do
    before do
      stub_overview(klass_to_overview)
    end

    it "should return an overview" do
      expect(klass_to_overview).to receive(asserted_message_expectation).with(*asserted_message_args).once
      2.times { run_overview }
      subject.timeframe = :month
      expect(klass_to_overview).to receive(asserted_message_expectation).with(*asserted_message_args(:timeframe => :month)).once
      2.times { run_overview }
    end
  end

  describe "#new_users" do
    let(:klass_to_overview) { User }

    def run_overview
      subject.new_users
    end

    it_should_behave_like "an overview method"
  end

  describe "#messages_received" do
    let(:klass_to_overview) { Message }

    def run_overview
      subject.messages_received
    end

    it_should_behave_like "an overview method"
  end

  describe "#users_texting" do
    let(:klass_to_overview) { Message }

    def run_overview
      subject.users_texting
    end

    def asserted_options(overridden = {})
      super.merge(:by_user => true)
    end

    it_should_behave_like "an overview method"
  end

  describe "#inbound_cdrs" do
    let(:klass_to_overview) { InboundCdr }

    def run_overview
      subject.inbound_cdrs
    end

    it_should_behave_like "an overview method"
  end

  describe "#phone_calls" do
    let(:klass_to_overview) { PhoneCall }

    def run_overview
      subject.phone_calls
    end

    it_should_behave_like "an overview method"
  end

  describe "#ivr_bill_minutes" do
    let(:klass_to_overview) { InboundCdr }

    def run_overview
      subject.ivr_bill_minutes
    end

    def asserted_message_expectation
      :overview_of_duration
    end

    it_should_behave_like "an overview method"
  end

  describe "#return_users" do
    before do
      stub_overview(User, [[1360886400000, 3], [1361232000000, 1]])
      stub_overview(Message, [[1360886400000, 6], [1361232000000, 3]])
    end

    it "should return an overview of the active users who are not new" do
      expect(subject.return_users).to eq([[1360886400000, 3], [1361232000000, 2]])
    end
  end
end
