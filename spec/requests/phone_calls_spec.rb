require 'rails_helper'

describe "PhoneCalls" do
  describe "POST /phone_calls.xml" do
    include PhoneCallHelpers
    include PhoneCallHelpers::TwilioHelpers
    include MobilePhoneHelpers
    include TranslationHelpers
    include ActiveJobHelpers

    include_context "replies"
    include_context "existing users"
    include_context "twiml"

    let(:twiml_response) { parse_twiml(response.body) }
    let(:my_number) { "855977123876" }
    let(:new_user) { User.where(:mobile_number => my_number).first }
    let(:caller) { create(:user) }

    def current_call(options = {})
      options.is_a?(PhoneCall) ? @call_sid = options.sid : @call_sid ||= make_call(options)
    end

    alias :call :current_call

    def phone_call_callback_url
      phone_calls_url(:format => :xml)
    end

    def assert_redirect_to_current_url
      assert_redirect(twiml_response, phone_call_callback_url)
    end

    def assert_play_then_redirect_to_current_url(file)
      assert_play(twiml_response, "kh/#{filename_with_extension(file)}")
      assert_redirect_to_current_url
    end

    def assert_dial_to_current_url(number, dial_options = {}, number_options = {})
      numbers = [number].flatten
      assert_dial(twiml_response, phone_call_callback_url, dial_options) do |dial_response|
        numbers.each_with_index do |number, index|
          assert_number(dial_response, number, number_options.merge(:index => index))
        end
      end
    end

    def assert_ask_for_input(prompt, twiml_options = {})
      twiml_options[:numDigits] ||= 1
      twiml_options[:numDigits] = twiml_options[:numDigits].to_s
      assert_gather(twiml_response, twiml_options) do |gather|
        assert_play(gather, "kh/#{filename_with_extension(prompt)}")
      end
      assert_redirect_to_current_url
    end

    def update_current_call_status(options = {})
      options[:call_sid] ||= current_call
      update_call_status(options)
    end

    def friends_numbers(friends, calling_to)
      friends.map { |friend|
        number = friend.mobile_number
        calling_to == :twilio ? asserted_number_formatted_for_twilio(number) : asserted_default_pbx_dial_string(:number_to_dial => number)
      }.reverse
    end

    shared_examples_for "saving the phone call" do
      it "should save the phone call" do
        new_phone_call = PhoneCall.last
        expect(new_phone_call.from).to eq(from)
      end
    end

    context "given that I'm already in a chat session" do
      context "and my partner is available" do
        let!(:chat) { create(:chat, :active, :user => caller) }

        context "when I call" do
          before do
            call(:from => caller)
          end

          it "should connect me with my friend" do
            assert_dial_to_current_url(
              asserted_number_formatted_for_twilio(chat.friend.mobile_number),
              :callerId => twilio_number
            )
          end
        end
      end

      context "but my partner is not available" do
        let(:friend) { create(:user, :from_unknown_operator) }
        let!(:chat) { create(:chat, :initiator_active, :user => caller, :friend => friend) }

        before do
          create(:chat, :active, :friend => chat.friend)
        end

        context "when I call" do
          before do
            call(:from => caller)
          end

          it "should find me some new friends" do
            assert_redirect_to_current_url
          end

          it "should queue a message to my partner to call me back" do
            reply = reply_to(chat.friend, chat)
            expect(reply.body).to match(Regexp.new(
              spec_translate(
                :contact_me, chat.friend.locale, chat.user.screen_id,
                Regexp.escape(twilio_number)
              )
            ))
            expect(reply).not_to be_delivered
          end
        end
      end
    end

    context "given there are new friends online" do
      let(:friends) { caller.matches }
      let(:caller) { User.first }

      before do
        load_users
        caller
        friends
      end

      context "when I call" do
        before do
          call(:from => caller.mobile_number)
        end

        it "should try to find me some new friends" do
          assert_redirect_to_current_url
        end

        context "after some new friends are found for me" do
          context "given I'm calling to Twilio" do
            before do
              update_current_call_status
            end

            it "should try to connect me with them through Twilio" do
              numbers = friends_numbers(friends, :twilio)
              assert_dial_to_current_url(numbers, :callerId => twilio_number)
            end

            context "if someone answers" do
              context "and hangs up first" do
                let(:dial_call_sid) { "dial_call_sid" }

                before do
                  expect_twilio_cdr_fetch(:call_sid => current_call) do
                    expect_twilio_cdr_fetch(
                      :cassette => "get_outbound_call",
                      :call_sid => dial_call_sid,
                      :parent_call_sid => current_call,
                      :direction => :outbound
                    ) do
                       trigger_job do
                        update_current_call_status(
                          :dial_call_status => :completed, :dial_call_sid => dial_call_sid
                        )
                      end
                    end
                  end
                end

                context "when I hold the line" do
                  let(:new_inbound_twilio_cdr) { Chibi::Twilio::InboundCdr.last }
                  let(:new_outbound_twilio_cdr) { Chibi::Twilio::OutboundCdr.last }

                  before do
                    update_current_call_status
                  end

                  it "should hangup on me" do
                    assert_hangup(twiml_response)
                  end

                  it "should create a Twilio Inbound CDR" do
                    expect(new_inbound_twilio_cdr).to be_present
                  end

                  it "should create a Twilio Outbound CDR" do
                    expect(new_outbound_twilio_cdr).to be_present
                  end
                end
              end
            end

            context "if nobody answers" do
              before do
                update_current_call_status(:dial_call_status => :no_answer)
              end

              it "should find me some new friends" do
                assert_redirect_to_current_url
              end

              context "and I hold the line" do
                before do
                  update_current_call_status
                end

                it "should connnect me with my new friends" do
                  numbers = friends_numbers(friends, :twilio)
                  assert_dial_to_current_url(numbers, :callerId => twilio_number)
                end
              end
            end
          end

          context "given I'm calling to 2442" do
            before do
              update_current_call_status(:api_version => sample_adhearsion_twilio_api_version)
            end

            it "should try to connect me with her through the default PBX dial string" do
              dial_strings = friends_numbers(friends, :pbx)
              assert_dial_to_current_url(dial_strings, {}, :callerId => twilio_number)
            end
          end
        end
      end
    end

    context "when I call" do
      context "given I am offline" do
        let(:offline_user) { create(:user, :offline) }

        before do
          call(:from => offline_user)
        end

        it "should put me online" do
          expect(offline_user.reload).to be_online
        end
      end

      context "to Twilio" do
        before do
          call(:from => my_number)
        end

        it_should_behave_like "saving the phone call" do
          let(:from) { my_number }
        end
      end
    end

    context "when I call to the short code '2442'" do
      before do
        call(:from => "+85510236139", :to => "+2442", :api_version => "adhearsion-twilio-0.0.1")
      end

      it_should_behave_like "saving the phone call" do
        let(:from) { "85510236139" }
      end
    end

    context "when I call to a number from the Twilio number" do
      before do
        call(:from => twilio_number, :to => "+85510236139")
      end

      it_should_behave_like "saving the phone call" do
        let(:from) { "85510236139" }
      end
    end

    context "when I am called" do
      context "and I answer" do
        before do
          call(:to => my_number)
        end

        it_should_behave_like "saving the phone call" do
          let(:from) { my_number }
        end
      end
    end
  end
end
