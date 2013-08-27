require 'spec_helper'

describe PhoneCall do
  include PhoneCallHelpers::States
  include PhoneCallHelpers::TwilioHelpers
  include ResqueHelpers
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
    let(:excluded_resource) { nil }

    def create_resources(count, *args)
      create_list(:phone_call, count, *args)
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
      subject.sid = 123
      subject.call_sid.should == 123

      subject.call_sid = 456
      subject.sid.should == 456
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

  describe "#login_user!" do
    let(:phone_call_from_offline_user) { create(:phone_call, :from_offline_user) }

    it "should delegate to user#login!" do
      phone_call_from_offline_user.login_user!
      phone_call_from_offline_user.user.should be_online
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

  describe ".find_or_create_and_process_by" do
    include PhoneCallHelpers

    def sample_params(options = {})
      options[:digits] ||= 1
      params = {}
      call_params(options).each do |key, value|
        params[key] = value || key.to_s.underscore.dasherize
      end
      params
    end

    it "should find or create the phone call and process it returning the phone call if valid" do
      params = sample_params

      subject.class.stub(:find_or_create_by).and_return(phone_call)

      phone_call.should_receive(:login_user!)
      phone_call.should_receive(:process!)
      subject.class.find_or_create_and_process_by(params.dup, "http://example.com").should == phone_call

      phone_call.redirect_url.should == "http://example.com"
      phone_call.digits.should == params[:Digits].to_i
      phone_call.call_status.should == params[:CallStatus]
      phone_call.dial_status.should == params[:DialCallStatus]
      phone_call.dial_call_sid.should == params[:DialCallSid]
      phone_call.api_version.should == params[:ApiVersion]

      subject.should_not_receive(:login_user!)
      subject.should_not_receive(:process!)
      subject.class.stub(:find_or_create_by).and_return(subject)
      subject.stub(:new_record?).and_return(false)
      subject.class.find_or_create_and_process_by(params.dup, "http://example.com").should be_nil
    end
  end

  describe "#process!" do
    include TranslationHelpers

    include_context "replies"

    def assert_phone_call_can_be_completed(reference_phone_call)
      reference_phone_call.call_status = "completed"
      do_background_task(:queue_only => true) { reference_phone_call.process! }
      reference_phone_call.should be_completed
      TwilioCdrFetcher.should have_queued(reference_phone_call.id)
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
        registered_operator(:dial_string), :number_to_dial => registered_operator_number
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
        registered_operator(:dial_string), :number_to_dial => partners_number
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
