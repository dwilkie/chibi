require 'spec_helper'

include PhoneCallHelpers::States
include PhoneCallHelpers::Twilio

describe PhoneCall do
  let(:phone_call) { create(:phone_call) }
  let(:new_phone_call) { build(:phone_call) }

  describe "factory" do
    it "should be valid" do
      new_phone_call.should be_valid
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

  it_should_behave_like "communicable" do
    let(:communicable_resource) { new_phone_call }
  end

  it_should_behave_like "communicable from user" do
    let(:communicable_resource) { new_phone_call }
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

  describe "#to" do
    # phone calls should behave the same whether they were initiated by
    # the user or not
    it "should be an accessor that overrides #from if present but if #to is a twilio number" do

      # test override
      subject.from = "+1-2345-2222"
      subject.to = "+1-2345-3333"
      subject.from.should == "123453333"

      # test no override for blank 'to'
      subject.to = ""
      subject.from.should == "123453333"

      # test no override for a 'to' which is a twilio number
      subject.from = "+1-2345-2222"
      twilio_numbers.each do |number|
        subject.to = number
        subject.from.should == "123452222"
      end
    end

    it "should be mass assignable" do
      new_phone_call = subject.class.new(:from => "+1-2345-2222", :to => "+1-2345-3333")
      new_phone_call.from.should == "123453333"
    end
  end

  describe "#digits" do
    it "should be an accessor but return the set value as an integer" do
      subject.digits = "1234"
      subject.digits.should == 1234
    end
  end

  describe "#login_user!" do
    let(:phone_call_from_offline_user) { create(:phone_call_from_offline_user) }

    it "should delegate to user#login!" do
      phone_call_from_offline_user.login_user!
      phone_call_from_offline_user.user.should be_online
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

      subject.class.stub(:find_or_initialize_by_sid).and_return(phone_call)

      phone_call.should_receive(:login_user!)
      phone_call.should_receive(:process!)
      subject.class.find_or_create_and_process_by(params.dup, "http://example.com").should == phone_call

      phone_call.redirect_url.should == "http://example.com"
      phone_call.digits.should == params[:Digits].to_i
      phone_call.call_status.should == params[:CallStatus]
      phone_call.dial_status.should == params[:DialCallStatus]

      subject.should_not_receive(:login_user!)
      subject.should_not_receive(:process!)
      subject.class.stub(:find_or_initialize_by_sid).and_return(subject)
      subject.class.find_or_create_and_process_by(params.dup, "http://example.com").should be_nil
    end
  end

  describe "#process!" do
    def assert_phone_call_can_be_completed(reference_phone_call)
      reference_phone_call.call_status = "completed"
      reference_phone_call.process!
      reference_phone_call.should be_completed

      # assert chat is expired for caller
      if chat = reference_phone_call.chat
        chat.should_not be_active
        chat.active_users.should_not include(phone_call.user)
      end
    end

    def assert_phone_call_attributes(resource, expectations)
      expectations.each do |attribute, value|
        if value.is_a?(Hash)
          assert_phone_call_attributes(resource.send(attribute), value)
        else
          resource.send(attribute).should == value
        end
      end
    end

    it "should transition to the correct state" do
      with_phone_call_states do |factory_name, twiml_expectation, phone_call_state, next_state, sub_factories|
        assert_phone_call_can_be_completed(build(factory_name))

        phone_call = build(factory_name)
        phone_call.process!
        phone_call.should send("be_#{next_state}")

        sub_factories.each do |sub_factory_name, sub_factory_attributes|
          next_sub_factory_state = sub_factory_attributes.keys.first
          expectations = sub_factory_attributes.values.first["expectations"] || {}

          phone_call = build(sub_factory_name)
          phone_call.process!
          phone_call.should send("be_#{next_sub_factory_state}")

          assert_phone_call_attributes(phone_call, expectations)
        end
      end
    end
  end

  describe "#to_twiml" do

    include_context "twiml"
    include_context "existing users"

    let(:redirect_url) { authenticated_url("http://example.com/twiml") }

    def twiml_response(resource)
      resource.redirect_url = redirect_url
      parse_twiml(resource.to_twiml)
    end

    def assert_dial_to_redirect_url(phone_call, options = {})
      twiml_options = options.dup
      user_to_dial = phone_call.chat.partner(phone_call.user)
      number_to_dial = user_to_dial.mobile_number

      twiml_options[:callerId] ||= twiml_options.delete(:twilio_number) ? user_to_dial.twilio_number : user_to_dial.short_code
      assert_dial(twiml_response(phone_call), redirect_url, number_to_dial, twiml_options)
    end

    def assert_play_languages(phone_call, filename, options = {})
      user = phone_call.user
      filename_with_extension = filename_with_extension(filename)

      twiml = twiml_response(phone_call)

      assert_play(twiml, "#{user.locale}/#{filename_with_extension}", options)
      assert_redirect(twiml, redirect_url, options)

      original_location = user.location
      user.location = build(:united_states)

      flunk(
        "choose a location with no translation to test the default locale"
      ) if I18n.available_locales.include?(user.locale)

      assert_play(twiml_response(phone_call), "en/#{filename_with_extension}", options)
      user.location = original_location
    end

    def assert_ask_for_input(phone_call, prompt, twiml_options = {})
      # automatically asserts redirect
      assert_play_languages(phone_call, prompt)
      filename_with_extension = filename_with_extension(prompt)

      twiml_options["numDigits"] ||= 1
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

    def assert_dial_friend(phone_call)
      # load some users
      load_users
      users_from_registered_service_providers

      # assert dial from the twilio number for users from a service provider without short code
      assert_dial_to_redirect_url(phone_call, :twilio_number => true)

      # assert dial from the user's friend's short code for users from registered service provider
      phone_call.chat = create(
        :active_chat, :user => phone_call.user, :friend => users_from_registered_service_providers.first
      )

      assert_dial_to_redirect_url(phone_call)
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

    context "given the redirect url has been set" do
      it "should return the correct twiml" do
        with_phone_call_states do |factory_name, expectation|
          assert_twiml_response(build(factory_name), expectation)
        end
      end
    end
  end
end
