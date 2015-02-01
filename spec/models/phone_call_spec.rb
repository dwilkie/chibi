require 'rails_helper'

describe PhoneCall do
  include PhoneCallHelpers::States
  include PhoneCallHelpers::TwilioHelpers
  include ActiveJobHelpers
  include AnalyzableExamples

  let(:phone_call) { create(:phone_call) }
  let(:new_phone_call) { build(:phone_call) }

  def create_phone_call(*traits)
    options = traits.extract_options!
    options[:build] ? build(:phone_call, *traits) : create(:phone_call, *traits)
  end

  describe "factory" do
    it "should be valid" do
      new_phone_call.should be_valid
    end
  end

  it_should_behave_like "analyzable" do
    let(:group_by_column) { :created_at }

    def create_resource(*args)
      create(:phone_call, *args)
    end
  end

  it "should not be valid without an sid" do
    new_phone_call.sid = nil
    new_phone_call.should_not be_valid
  end

  it "should not be valid with a duplicate sid" do
    new_phone_call.sid = phone_call.sid
    new_phone_call.should_not be_valid
  end

  it "should not be valid with a duplicate dial_call_sid" do
    phone_call = create(:phone_call, :with_dial_call_sid)
    new_phone_call.dial_call_sid = phone_call.dial_call_sid
    new_phone_call.should_not be_valid
  end

  it_should_behave_like "a chat starter" do
    let(:starter) { phone_call }
  end

  it_should_behave_like "communicable" do
    let(:communicable_resource) { phone_call }
  end

  it_should_behave_like "communicable from user" do
    let(:communicable_resource) { phone_call }
  end

  it_should_behave_like "chatable" do
    let(:chatable_resource) { phone_call }
  end

  describe "#call_sid" do
    it "should be an alias for the attribute '#sid'" do
      subject.sid = "123"
      subject.call_sid.should == "123"

      subject.call_sid = "456"
      subject.sid.should == "456"
    end
  end

  describe "#redirect_url" do
    it "should be an accessor" do
      subject.redirect_url = "some_url"
      subject.redirect_url.should == "some_url"
    end
  end

  describe "#dial_status" do
    it "should be an accessor" do
      subject.dial_status = "some_status"
      subject.dial_status.should == "some_status"
    end
  end

  describe "#call_status" do
    it "should be an accessor" do
      subject.call_status = "some_call_status"
      subject.call_status.should == "some_call_status"
    end
  end

  describe "#to=(value)" do
    # phone calls should behave the same whether they were initiated by the user or not
    it "should override #from=(value) if present" do
      # test override
      subject.from = "+1-234-567-8910"
      subject.to = "+1-229-876-5432"
      subject.from.should == "12298765432"

      # test no override for blank 'to'
      subject.to = ""
      subject.from.should == "12298765432"
    end

    it "should be mass assignable" do
      new_phone_call = subject.class.new(:from => "+1-234-567-8910", :to => "+1-229-876-5432")
      new_phone_call.from.should == "12298765432"
    end
  end

  describe "#digits" do
    it "should be an accessor but return the set value as an integer" do
      subject.digits = "1234"
      subject.digits.should == 1234
    end
  end

  describe "#fetch_inbound_twilio_cdr!" do
    it "should create a Chibi Twilio Inbound CDR" do
      expect_twilio_cdr_fetch(:call_sid => phone_call.sid) { phone_call.fetch_inbound_twilio_cdr! }
      Chibi::Twilio::InboundCdr.last.phone_call.should == phone_call
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

        Chibi::Twilio::OutboundCdr.last.phone_call.should == phone_call
      end
    end

    context "given the phone call does not have a dial_call_sid" do
      it "should not create a Chibi Twilio Outbound CDR" do
        phone_call.fetch_outbound_twilio_cdr!
        Chibi::Twilio::OutboundCdr.last.should be_nil
      end
    end
  end

  describe ".find_or_create_and_process_by(params, redirect_url)" do
    include PhoneCallHelpers

    let(:redirect_url) { "http://example.com" }
    let(:call_sid) { generate(:guid) }
    let(:from) { generate(:mobile_number) }
    let(:to) { "2441" }
    let(:params) { sample_params(:from => from, :to => to, :call_sid => call_sid) }
    let(:user) { create(:user) }
    let(:phone_call) { create(:phone_call, :user => user) }

    def sample_params(options = {})
      options[:digits] ||= 1
      params = {}
      call_params(options).each do |key, value|
        params[key] = value || key.to_s.underscore.dasherize
      end
      params
    end

    context "phone call is valid" do
      def do_find_or_create_and_process
        subject.class.find_or_create_and_process_by(params.dup, redirect_url)
      end
      before do
        subject.class.stub(:find_or_initialize_by).and_return(phone_call)
      end

      it "should update the phone call" do
        do_find_or_create_and_process

        phone_call.redirect_url.should == redirect_url
        phone_call.digits.should == params[:Digits].to_i
        phone_call.call_status.should == params[:CallStatus]
        phone_call.dial_status.should == params[:DialCallStatus]
        phone_call.dial_call_sid.should == params[:DialCallSid]
        phone_call.api_version.should == params[:ApiVersion]
      end

      it "should log in the user" do
        user.should_receive(:login!)
        do_find_or_create_and_process
      end

      context "there's a charge request for this call" do
        let(:charge_request) { create(:charge_request, :requester => phone_call) }

        before do
          phone_call.stub(:charge_request).and_return(charge_request)
          charge_request.stub(:slow?)
        end

        it "should ask if the charge request is slow" do
          charge_request.should_receive(:slow?)
          do_find_or_create_and_process
        end

        context "and it's slow (see charge_request#slow?)" do
          before do
            charge_request.stub(:slow?).and_return(true)
          end

          it "should process the phone call" do
            phone_call.should_receive(:process!)
            do_find_or_create_and_process
          end
        end

        context "but it's not slow" do
          before do
            charge_request.stub(:slow?).and_return(false)
          end

          it "should not process the phone call" do
            phone_call.should_not_receive(:process!)
            do_find_or_create_and_process
          end
        end
      end

      context "there's no charge request for this call" do
        it "should try to charge the caller" do
          user.should_receive(:charge!).with(phone_call)
          do_find_or_create_and_process
        end

        context "given the charge request returns true" do
          before do
            user.stub(:charge!).and_return(true)
          end

          it "should process the phone call" do
            phone_call.should_receive(:process!)
            do_find_or_create_and_process
          end
        end

        context "given the charge request returns nil" do
          before do
            user.stub(:charge!).and_return(nil)
          end

          it "should not process the phone call" do
            phone_call.should_not_receive(:process!)
            do_find_or_create_and_process
          end
        end
      end
    end

    context "phone call is invalid" do
      let(:params) { sample_params(:from => "+2441", :to => "+2441") }

      it "should not process the phone call" do
        subject.class.find_or_create_and_process_by(params.dup, redirect_url).should be_nil
      end
    end

    context "phone call is new" do
      it "should save the phone call" do
        phone_call = subject.class.find_or_create_and_process_by(params, redirect_url)
        phone_call.should be_persisted
        phone_call.sid.should == call_sid
        phone_call.from.should == from
      end
    end

    context "phone call already exists" do
      before do
        create(:phone_call, :sid => call_sid)
      end

      it "should not update the from field" do
        phone_call = subject.class.find_or_create_and_process_by(params, redirect_url)
        phone_call.should be_persisted
        phone_call.sid.should == call_sid
        phone_call.from.should_not == from
      end
    end
  end

  describe "#process!" do
    include TranslationHelpers

    include_context "replies"

    def assert_phone_call_can_be_completed(reference_phone_call)
      reference_phone_call.call_status = "completed"
      already_complete = reference_phone_call.completed?
      clear_enqueued_jobs
      trigger_job(:queue_only => true) { reference_phone_call.process! }
      reference_phone_call.should be_completed
      job = enqueued_jobs.first
      if already_complete
        expect(job).to eq(nil)
      else
        expect(job[:args].first).to eq(reference_phone_call.id)
      end
    end

    def assert_message_queued_for_partner(phone_call)
      caller = phone_call.user.reload
      old_chat = phone_call.chat
      old_partner = old_chat.partner(caller)
      reply = reply_to(old_partner, old_chat)
      reply.body.should =~ Regexp.new(
        spec_translate(
          :contact_me, old_partner.locale, caller.screen_id,
          Regexp.escape(old_partner.caller_id(phone_call.api_version))
        )
      )
      reply.should_not be_delivered
      caller.should_not be_currently_chatting
      phone_call.triggered_chats.should_not be_empty
    end

    def assert_phone_call_attributes(resource, expectations)
      expectations.each do |attribute, value|
        if value.is_a?(Hash)
          assert_phone_call_attributes(resource.send(attribute), value)
        else
          if attribute == "assertions"
            value.each do |assertion|
              send("assert_#{assertion}", resource)
            end
          else
            resource.send(attribute).should == value
          end
        end
      end
    end

    def assert_correct_transition(options = {})
      with_phone_call_states(options) do |state, traits, next_state, twiml_expectation, substates|
        assert_phone_call_can_be_completed(create_phone_call(state, *traits))

        phone_call = create_phone_call(state, *traits)
        phone_call.process!
        phone_call.should send("be_#{next_state}")

        substates.each do |substate_trait, substate_attributes|
          if substate_attributes.is_a?(Hash)
            next_state_from_substate = substate_attributes["next_state"]
            expectations = substate_attributes["expectations"]
          else
            next_state_from_substate = substate_attributes
            expectations = {}
          end

          phone_call = create_phone_call(state, substate_trait.to_sym, *traits)
          phone_call.process!
          phone_call.should send("be_#{next_state_from_substate}")

          assert_phone_call_attributes(phone_call, expectations)
        end
      end
    end

    it "should transition to the correct state" do
      assert_correct_transition(:voice_prompts => false)
    end
  end

  describe "#to_twiml" do
    include MobilePhoneHelpers

    include_context "twiml"
    include_context "existing users"

    let(:redirect_url) { authenticated_url("http://example.com/twiml") }

    def twiml_response(resource)
      resource.redirect_url = redirect_url
      parse_twiml(resource.to_twiml)
    end

    def assert_dial_to_redirect_url(twiml, asserted_numbers, dial_options = {}, number_options = {})
      assert_dial(twiml, redirect_url, dial_options) do |dial_twiml|
        if asserted_numbers.is_a?(String)
          assert_number(dial_twiml, asserted_numbers, number_options)
        elsif asserted_numbers.is_a?(Array)
          asserted_numbers.each_with_index do |asserted_number, index|
            assert_number(dial_twiml, asserted_number, number_options.merge(:index => index))
          end
        elsif asserted_numbers.is_a?(Hash)
          asserted_numbers.each_with_index do |(asserted_number, asserted_number_options), index|
            assert_number(dial_twiml, asserted_number, asserted_number_options.merge(:index => index))
          end
        end
      end
    end

    def assert_play_languages(phone_call, filename, options = {})
      user = phone_call.user
      filename_with_extension = filename_with_extension(filename)

      twiml = twiml_response(phone_call)

      assert_play(twiml, "#{user.locale}/#{filename_with_extension}", options)
      assert_redirect(twiml, redirect_url, options)

      phone_call.user = create(:user, :american)

      flunk(
        "choose a location with no translation to test the default locale"
      ) if I18n.available_locales.include?(phone_call.user.locale)

      assert_play(twiml_response(phone_call), "en/#{filename_with_extension}", options)
      phone_call.user = user
    end

    def assert_ask_for_input(phone_call, prompt, twiml_options = {})
      # automatically asserts redirect
      assert_play_languages(phone_call, prompt)
      filename_with_extension = filename_with_extension(prompt)

      twiml_options.symbolize_keys!

      twiml_options[:numDigits] ||= 1
      twiml_options[:numDigits] = twiml_options[:numDigits].to_s
      assert_gather(twiml_response(phone_call), twiml_options) do |gather|
        assert_play(gather, "#{phone_call.user.locale}/#{filename_with_extension}")
      end
    end

    def assert_no_response(phone_call)
      phone_call.to_twiml.should be_empty
    end

    def assert_redirect_to_current_url(phone_call)
      assert_redirect(twiml_response(phone_call), redirect_url)
    end

    def assert_hangup_current_call(phone_call)
      assert_hangup(twiml_response(phone_call))
    end

    def find_friends(phone_call, with_mobile_numbers)
      with_mobile_numbers.each do |mobile_number|
        create(
          :chat, :friend_active,
          :user => phone_call.user, :starter => phone_call,
          :friend => create(:user, :mobile_number => mobile_number)
        )
      end
    end

    def assert_dial_friends(phone_call)
      # assert correct TwiML for Twilio request

      non_registered_operator_number = generate(:mobile_number)
      registered_operator_number = registered_operator(:number)

      sample_numbers = [non_registered_operator_number, registered_operator_number]

      find_friends(phone_call, sample_numbers)
      asserted_numbers = sample_numbers.map { |sample_number| asserted_number_formatted_for_twilio(sample_number) }.reverse

      assert_dial_to_redirect_url(
        twiml_response(phone_call), asserted_numbers, :callerId => twilio_number
      )

      # Simulate an adhearsion-twilio request
      phone_call.api_version = sample_adhearsion_twilio_api_version

      asserted_registered_operator_dial_string = interpolated_assertion(
        registered_operator(:dial_string),
        :number_to_dial => registered_operator_number,
        :dial_string_number_prefix => registered_operator(:dial_string_number_prefix),
        :voip_gateway_host => registered_operator(:voip_gateway_host)
      )

      asserted_non_registered_operator_dial_string = asserted_default_pbx_dial_string(
        :number_to_dial => non_registered_operator_number
      )

      asserted_numbers = {
        asserted_registered_operator_dial_string => {
          :callerId => registered_operator(:caller_id)
        },
        asserted_non_registered_operator_dial_string => {
          :callerId => twilio_number
        }
      }

      assert_dial_to_redirect_url(
        twiml_response(phone_call), asserted_numbers
      )
    end

    def assert_dial_partner(phone_call)
      # assert correct TwiML for Twilio request
      user_to_dial = phone_call.chat.partner(phone_call.user)
      asserted_number = asserted_number_formatted_for_twilio(user_to_dial.mobile_number)

      assert_dial_to_redirect_url(
        twiml_response(phone_call), asserted_number, :callerId => twilio_number
      )

      # Simulate an adhearsion-twilio request
      phone_call.api_version = sample_adhearsion_twilio_api_version

      # assert correct TwiML when dialing to a user from an unregistered service provider
      asserted_number = asserted_default_pbx_dial_string(:number_to_dial => user_to_dial.mobile_number)
      assert_dial_to_redirect_url(
        twiml_response(phone_call), asserted_number, {}, :callerId => twilio_number
      )

      # assert correct TwiML when dialing to a user from registered service provider
      partners_number = registered_operator(:number)
      asserted_number = interpolated_assertion(
        registered_operator(:dial_string),
        :number_to_dial => partners_number,
        :dial_string_number_prefix => registered_operator(:dial_string_number_prefix),
        :voip_gateway_host => registered_operator(:voip_gateway_host)
      )

      phone_call.chat = create(
        :chat, :active, :user => phone_call.user,
        :friend => create(:user, :mobile_number => partners_number),
        :starter => phone_call
      )

      assert_dial_to_redirect_url(
        twiml_response(phone_call), asserted_number, {}, :callerId => registered_operator(:caller_id)
      )
    end

    def assert_twiml_response(phone_call, expectation)
      if expectation.is_a?(Hash)
        assertion_method = expectation.keys.first
        assertion_args = expectation.values
        assertion_args = assertion_args.first.flatten if assertion_args.first.is_a?(Hash)
      else
        assertion_method = expectation
      end
      assertion_args ||= []
      send("assert_#{assertion_method}", phone_call, *assertion_args)
    end

    def assert_correct_twiml(options = {})
      with_phone_call_states(options) do |state, traits, next_state, expectation|
        assert_twiml_response(create_phone_call(state, *traits), expectation)
      end
    end

    context "given the redirect url has been set" do
      it "should return the correct TwiML" do
        assert_correct_twiml(:voice_prompts => false)
      end
    end
  end
end
