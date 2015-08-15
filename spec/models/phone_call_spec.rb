require 'rails_helper'

describe PhoneCall do
  include PhoneCallHelpers
  include PhoneCallHelpers::TwilioHelpers
  include ActiveJobHelpers
  include AnalyzableExamples

  let(:phone_call) { create(:phone_call) }
  let(:new_phone_call) { build(:phone_call) }

  def sample_call_params(options = {})
    params = {}
    super(options).each do |key, value|
      params[key] = value || key.to_s.underscore.dasherize
    end
    params
  end

  describe "validations" do
    subject { build(:phone_call) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:sid) }
  end

  it_should_behave_like "analyzable" do
    let(:group_by_column) { :created_at }

    def create_resource(*args)
      create(:phone_call, *args)
    end
  end

  it_should_behave_like "a chat starter" do
    let(:starter) { phone_call }
  end

  it_should_behave_like "communicable from user" do
    subject { phone_call }
  end

  it_should_behave_like "chatable" do
    let(:chatable_resource) { phone_call }
  end

  describe "#pre_process!" do
    subject { create(:phone_call, :user => user) }
    let(:user) { create(:user) }

    def set_expectations
      expect(user).to receive(:charge!).with(subject)
    end

    before do
      set_expectations
      subject.pre_process!
    end

    context "user is offline" do
      let(:user) { create(:user, :offline) }
      it { expect(user).to be_online }
    end
  end

  describe "#call_sid" do
    it "should be an alias for the attribute '#sid'" do
      subject.sid = "123"
      expect(subject.call_sid).to eq("123")

      subject.call_sid = "456"
      expect(subject.sid).to eq("456")
    end
  end

  describe "#to=(value)" do
    # phone calls should behave the same whether they were initiated by the user or not
    it "should override #from=(value) if present" do
      # test override
      subject.from = "+1-234-567-8910"
      subject.to = "+1-229-876-5432"
      expect(subject.from).to eq("12298765432")

      # test no override for blank 'to'
      subject.to = ""
      expect(subject.from).to eq("12298765432")
    end

    it "should be mass assignable" do
      new_phone_call = subject.class.new(:from => "+1-234-567-8910", :to => "+1-229-876-5432")
      expect(new_phone_call.from).to eq("12298765432")
    end
  end

  describe "#anonymous?" do
    context "for anonymous calls" do
      subject { build(:phone_call, :anonymous) }
      it { is_expected.to be_anonymous }
    end

    context "for normal calls" do
      subject { build(:phone_call) }
      it { is_expected.not_to be_anonymous }
    end
  end

  describe "#fetch_inbound_twilio_cdr!" do
    include WebMockHelpers
    subject { create(:phone_call) }

    context "given the CDR has not already been saved" do
      it "should create a Chibi Twilio Inbound CDR" do
        expect_twilio_cdr_fetch(:call_sid => subject.sid) { subject.fetch_inbound_twilio_cdr! }
        expect(Chibi::Twilio::InboundCdr.last.phone_call).to eq(subject)
      end
    end

    context "given the CDR has already been saved" do
      before do
        expect_twilio_cdr_fetch(:call_sid => subject.sid) { subject.fetch_inbound_twilio_cdr! }
      end

      it "should not fetch the CDR" do
        WebMock.clear_requests!
        subject.fetch_inbound_twilio_cdr!
        expect(webmock_requests).to be_empty
      end
    end
  end

  describe "#fetch_outbound_twilio_cdr!" do
    context "given the phone call has a dial_call_sid" do
      let(:phone_call) { create(:phone_call, :with_dial_call_sid) }

      it "should create a Chibi Twilio Outbound CDR" do
        expect_twilio_cdr_fetch(
          :call_sid => phone_call.dial_call_sid, :direction => :outbound,
          :parent_call_sid => phone_call.sid
        ) { phone_call.fetch_outbound_twilio_cdr! }

        expect(Chibi::Twilio::OutboundCdr.last.phone_call).to eq(phone_call)
      end
    end

    context "given the phone call does not have a dial_call_sid" do
      it "should not create a Chibi Twilio Outbound CDR" do
        phone_call.fetch_outbound_twilio_cdr!
        expect(Chibi::Twilio::OutboundCdr.last).to be_nil
      end
    end
  end

  describe ".answer!(params, request_url)" do
    let(:request_url) { "http://example.com/phone_calls.xml" }
    let(:call_sid) { generate(:guid) }
    let(:from) { generate(:mobile_number) }
    let(:to) { "2441" }
    let(:call_params) { sample_call_params(:from => from, :to => to, :call_sid => call_sid) }

    let(:phone_call) { described_class.answer!(call_params, request_url) }

    it "should save the phone call" do
      expect(phone_call).to be_persisted
      expect(phone_call.sid).to eq(call_sid)
      expect(phone_call.from).to eq(from)
      expect(phone_call).to be_answered
      expect(phone_call.request_url).to eq(request_url)
    end

    context "call is from an anonymous user" do
      let(:from) { "Anonymous" }

      it { expect(phone_call).not_to be_persisted }
    end

    context "a race condition occurs when trying to create the user. See https://github.com/dwilkie/chibi/issues/203" do
      let(:new_user) { User.new(:mobile_number => from) }
      let(:existing_user) { create(:user, :mobile_number => from) }
      let(:race_conditions) { [new_user] * (SaveWithRetry::DEFAULT_MAX_TRIES - 1) }

      def setup_scenario
        existing_user
        allow(User).to receive(:find_or_initialize_by).with(:mobile_number => from).and_return(*race_conditions)
      end

      before do
        setup_scenario
      end

      context "after retrying the maximum number of times" do
        def setup_scenario
          race_conditions << new_user
          super
        end

        it { expect { phone_call }.to raise_error(ActiveRecord::RecordInvalid) }
      end

      context "after retrying it's successful" do
        def setup_scenario
          race_conditions << existing_user
          super
        end

        it { expect(phone_call).to be_persisted }
      end
    end
  end

  describe ".complete!(params)" do
    let(:call_duration) { 30 }

    it "should transition from all states to completed" do
      described_class.aasm.states.each do |state|
        phone_call = create(:phone_call, state.name)
        params = sample_call_params(:call_sid => phone_call.sid, :call_duration => call_duration)
        described_class.complete!(params)
        phone_call.reload
        expect(phone_call).to be_completed
        expect(phone_call.duration).to eq(call_duration)
      end
    end

    context "given the phone call cannot be found" do
      it { expect { described_class.complete!(:call_sid => "does-not-exist") }.not_to raise_error }
    end
  end

  describe "#process!" do
    include Rails.application.routes.url_helpers
    include_context "replies"

    def create_phone_call(*args)
      options = args.extract_options!
      create(:phone_call, current_state, *args, {:user => user}.merge(options))
    end

    def setup_scenario
    end

    subject { create_phone_call }

    let(:host) { "http://www.example.com" }
    let(:request_url) { phone_call_path(subject, :host => host, :format => :xml) }
    let(:call_params) { {} }
    let(:user) { create(:user, :offline) }

    before do
      setup_scenario
      subject.set_call_params(call_params, request_url)
      subject.process!
      subject.reload
    end

    context "current state is:" do
      context "transitioning_from" do
        context "answered" do
          let(:current_state) { :transitioning_from_answered }

          context "the charge request failed" do
            def setup_scenario
              create(:charge_request, :failed, :requester => subject)
            end

            it { expect(subject.reload).to be_telling_user_they_dont_have_enough_credit }
          end

          context "the user is not currently chatting" do
            it { expect(subject.reload).to be_finding_friends }

            context "given there are users available to chat" do
              def setup_scenario
                create(:user)
              end

              it { expect(subject.triggered_chats).not_to be_empty }
            end
          end

          context "the user is already in a chat" do
            def setup_scenario
              chat
            end

            def create_chat(*args)
              options = args.extract_options!
              create(:chat, *args, {:user => user}.merge(options))
            end

            context "that is active" do
              let(:chat) { create_chat(:active) }

              it { is_expected.to be_connecting_user_with_friend }
              it { expect(subject.chat).to eq(chat) }
            end

            context "that is not active" do
              let(:chat) { create_chat(:initiator_active, :friend => partner) }
              let(:partner) { create(:user) }

              context "but the partner is available" do
                it { is_expected.to be_connecting_user_with_friend }
                it { expect(subject.chat).to eq(chat) }
              end

              context "and the partner is no longer available" do
                let(:reply_to_partner) { reply_to(partner) }

                def setup_scenario
                  super
                  create(:user)
                  create(:chat, :active, :friend => partner) # partner is in active chat
                end

                it { is_expected.to be_finding_friends }
                it { expect(subject.triggered_chats).not_to be_empty }
                it { expect(subject.chat).to eq(chat) }

                it "should queue a message for the partner to receive when his available" do
                  expect(reply_to_partner).to be_present
                  expect(reply_to_partner).not_to be_delivered
                end
              end
            end
          end
        end

        context "telling_user_they_dont_have_enough_credit" do
          let(:current_state) { :transitioning_from_telling_user_they_dont_have_enough_credit }
          it { is_expected.to be_awaiting_completion }
        end

        context "connecting_user_with_friend" do
          let(:current_state) { :transitioning_from_connecting_user_with_friend }

          context "friend answered call" do
            let(:call_params) { sample_call_params(:dial_call_status => "completed") }
            it { is_expected.to be_awaiting_completion }
          end

          context "friend did not answer call" do
            let(:call_params) { sample_call_params(:dial_call_status => "no-answer") }
            it { is_expected.to be_finding_friends }
          end
        end

        context "finding_friends" do
          let(:current_state) { :transitioning_from_finding_friends }

          context "friends are found" do
            def setup_scenario
              create(:chat, :starter => subject)
            end

            it { is_expected.to be_dialing_friends }
          end

          context "friends are not found" do
            it { is_expected.to be_awaiting_completion }
          end
        end

        context "dialing_friends" do
          let(:current_state) { :transitioning_from_dialing_friends }

          context "call was answered" do
            let(:call_params) { sample_call_params(:dial_call_status => "completed") }
            it { is_expected.to be_awaiting_completion }
          end

          context "call was not answered" do
            def setup_scenario
              super
              create(:user)
            end

            it { is_expected.to be_finding_friends }
            it { expect(subject.triggered_chats).not_to be_empty }
          end
        end
      end
    end
  end

  describe "#flag_as_processing!"  do
    let(:call_params) { { "Foo" => "Bar" } }
    let(:request_url) { "https://example.com/phone_calls.xml" }
    let(:job) { enqueued_jobs.last }

    subject { create(:phone_call, current_state, :call_params => call_params) }

    before do
      subject.request_url = request_url
      subject.flag_as_processing!
      assert_job_queued!
      subject.reload
    end

    def assert_job_queued!
      args = job[:args]
      expect(job[:job]).to eq(PhoneCallProcessorJob)
      expect(args[0]).to eq(subject.id)
      expect(args[1]).to include(call_params)
      expect(args[2]).to eq(request_url)
    end

    context "current state is:" do
      context "answered" do
        let(:current_state) { :answered }

        it { is_expected.to be_transitioning_from_answered }
      end

      context "telling_user_they_dont_have_enough_credit" do
        let(:current_state) { :telling_user_they_dont_have_enough_credit }

        it { is_expected.to be_transitioning_from_telling_user_they_dont_have_enough_credit }
      end

      context "connecting_user_with_friend" do
        let(:current_state) { :connecting_user_with_friend }

        it { is_expected.to be_transitioning_from_connecting_user_with_friend }
      end

      context "finding_friends" do
        let(:current_state) { :finding_friends }

        it { is_expected.to be_transitioning_from_finding_friends }
      end

      context "dialing_friends" do
        let(:current_state) { :dialing_friends }

        it { is_expected.to be_transitioning_from_dialing_friends }
      end
    end
  end

  describe "#to_twiml" do
    include MobilePhoneHelpers
    include TwilioHelpers
    include TwilioHelpers::TwimlAssertions::RSpec
    include Rails.application.routes.url_helpers

    let(:host) { "http://www.example.com" }

    context "current state is:" do
      let(:user) { create(:user) }
      let(:twiml) { subject.to_twiml }
      let(:asserted_redirect_url) { phone_call_url(subject, :host => host, :format => :xml) }
      let(:request_url) { authenticated_url(phone_call_url(subject, :host => host, :format => :xml)) }
      let(:call_params) { sample_call_params }

      subject { create_phone_call }

      before do
        setup_scenario
        subject.set_call_params(call_params, request_url)
      end

      def setup_scenario
      end

      def create_phone_call(*args)
        options = args.extract_options!
        create(:phone_call, current_state, {:user => user}.merge(options))
      end

      context "answered" do
        let(:current_state) { :answered }
        let(:request_url) { authenticated_url(phone_calls_url(:host => host, :format => :xml)) }

        context "for a normal call" do
          it { assert_redirect! }
        end

        context "for an anonymous call" do
          let(:call_params) { sample_call_params(build(:phone_call, :anonymous).call_params.symbolize_keys) }
          it { assert_hangup! }
        end
      end

      context "telling_user_they_dont_have_enough_credit" do
        let(:current_state) { :telling_user_they_dont_have_enough_credit }
        let(:asserted_filename) { "#{asserted_locale}/not_enough_credit.mp3" }

        it { assert_redirect! }

        context "given the user is Khmer" do
          let(:user) { create(:user, :cambodian) }
          let(:asserted_locale) { "kh" }
          it { assert_play! }
        end

        context "given the user is Filipino" do
          let(:user) { create(:user, :filipino) }
          let(:asserted_locale) { "ph" }
          it { assert_play! }
        end
      end

      context "awaiting_completion" do
        let(:current_state) { :awaiting_completion }
        it { assert_hangup! }
      end

      context "completed" do
        let(:current_state) { :completed }
        it { assert_hangup! }
      end

      context "connecting_user_with_friend" do
        let(:current_state) { :connecting_user_with_friend }
        let(:partners_number) { generate(:mobile_number) }
        let(:partner) { create(:user, :mobile_number => partners_number) }
        let(:chat) { create(:chat, :active, :user => user, :friend => partner) }

        subject { create_phone_call(:chat => chat) }

        context "given the call was initiated from Twilio" do
          let(:call_params) { sample_call_params(:api_version => sample_twilio_api_version) }
          let(:asserted_caller_id) { twilio_number }

          it "should dial to the partner in Twilio format" do
            assert_dial!(:callerId => asserted_caller_id) do |dial_twiml|
              assert_number!(dial_twiml, asserted_number_formatted_for_twilio(partner.mobile_number))
            end
          end
        end

        context "given the call was not initiated from Twilio" do
          let(:call_params) { sample_call_params(:api_version => sample_adhearsion_twilio_api_version) }

          context "and the partner is from a registered operator" do
            let(:partners_number) { registered_operator(:number) }

            let(:asserted_number_to_dial) {
              interpolated_assertion(
                registered_operator(:dial_string),
                :number_to_dial => partners_number,
                :dial_string_number_prefix => registered_operator(:dial_string_number_prefix),
                :voip_gateway_host => registered_operator(:voip_gateway_host)
              )
            }

            let(:asserted_caller_id) { registered_operator(:caller_id) }
            let(:asserted_ringback_path) { asserted_ringback_tone(asserted_locale) }

            def assert_dial!
              super(:ringback => asserted_play_url(asserted_ringback_path)) do |dial_twiml|
                assert_number!(
                  dial_twiml,
                  asserted_number_to_dial,
                  :callerId => asserted_caller_id,
                )
              end
            end

            context "given the dialer is Khmer" do
              let(:user) { create(:user, :cambodian) }
              let(:asserted_locale) { "kh" }
              it { assert_dial! }
            end

            context "given the dialer is Filipino" do
              let(:user) { create(:user, :filipino) }
              let(:asserted_locale) { "ph" }
              it { assert_dial! }
            end
          end

          context "and the partner is not from a registered operator" do
            let(:partners_number) { generate(:unknown_operator_number) }

            it "should dial to the partner in adhearsion-twilio format" do
              asserted_number_to_dial = asserted_default_pbx_dial_string(:number_to_dial => partners_number)

              assert_dial! do |dial_twiml|
                assert_number!(dial_twiml, asserted_number_to_dial, :callerId => twilio_number)
              end
            end
          end
        end
      end

      context "finding_friends" do
        let(:current_state) { :finding_friends }
        it { assert_redirect! }
      end

      context "dialing_friends" do
        let(:current_state) { :dialing_friends }
        let(:non_registered_operator_number) { generate(:mobile_number) }
        let(:registered_operator_number) { registered_operator(:number) }

        let(:partner_from_registered_operator) { create(:user, :mobile_number => registered_operator_number) }
        let(:partner_from_non_registered_operator) { create(:user, :mobile_number => non_registered_operator_number) }

        let(:asserted_max_simultaneous_dials) { Rails.application.secrets[:phone_call_max_simultaneous_dials].to_i }

        def setup_scenario
          create_list(:chat, 5, :starter => subject)
          create(:chat, :starter => subject, :friend => partner_from_registered_operator)
          create(:chat, :starter => subject, :friend => partner_from_non_registered_operator)
        end

        context "given the call was initiated from Twilio" do
          let(:call_params) { sample_call_params(:api_version => sample_twilio_api_version) }

          it "should dial to the partners in Twilio format" do
            assert_dial!(:callerId => twilio_number) do |dial_twiml|
              assert_numbers_dialed!(dial_twiml, asserted_max_simultaneous_dials)

              assert_number!(
                dial_twiml,
                asserted_number_formatted_for_twilio(non_registered_operator_number),
                :index => 0
              )
              assert_number!(
                dial_twiml,
                asserted_number_formatted_for_twilio(registered_operator_number),
                :index => 1
              )
            end
          end
        end

        context "given the call was not initiated from Twilio" do
          let(:call_params) { sample_call_params(:api_version => sample_adhearsion_twilio_api_version) }

          it "should dial to the partners in adhearsion-twilio format" do
            assert_dial! do |dial_twiml|
              assert_numbers_dialed!(dial_twiml, asserted_max_simultaneous_dials)

              assert_number!(
                dial_twiml,
                asserted_default_pbx_dial_string(:number_to_dial => non_registered_operator_number),
                :callerId => twilio_number,
                :index => 0
              )

              assert_number!(
                dial_twiml,
                interpolated_assertion(
                  registered_operator(:dial_string),
                  :number_to_dial => registered_operator_number,
                  :dial_string_number_prefix => registered_operator(:dial_string_number_prefix),
                  :voip_gateway_host => registered_operator(:voip_gateway_host)
                ),
                :callerId => registered_operator(:caller_id),
                :index => 1
              )
            end
          end
        end
      end

      context "transitioning_from" do
        def assert_redirect!
          super(:method => "GET")
        end

        let(:request_url) { authenticated_url(phone_call_url(subject, :host => host, :format => :xml)) }

        context "answered" do
          let(:current_state) { :transitioning_from_answered }
          it { assert_redirect! }
        end

        context "telling_user_they_dont_have_enough_credit" do
          let(:current_state) { :transitioning_from_telling_user_they_dont_have_enough_credit }
          it { assert_redirect! }
        end

        context "connecting_user_with_friend" do
          let(:current_state) { :transitioning_from_connecting_user_with_friend }
          it { assert_redirect! }
        end

        context "finding_friends" do
          let(:current_state) { :transitioning_from_finding_friends }
          it { assert_redirect! }
        end

        context "dialing_friends" do
          let(:current_state) { :transitioning_from_dialing_friends }
          it { assert_redirect! }
        end
      end
    end
  end
end
